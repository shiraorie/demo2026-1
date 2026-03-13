#!/bin/bash
###############################################################################
# Скрипт автоматической установки Zabbix 6.0 на Debian 12
# Зеркало: Yandex Mirror
###############################################################################

set -e  # Остановка при ошибке

# === КОНФИГУРАЦИЯ ===
DB_PASSWORD="P@ssw0rd"
DB_NAME="zabbix"
DB_USER="zabbix"
ZABBIX_HOSTNAME="mon.au-team.irpo"
TIMEZONE="Asia/Yekaterinburg"
ADMIN_PASSWORD="P@ssw0rd"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен от root"
   exit 1
fi

# Проверка ОС
if [[ ! -f /etc/debian_version ]] || [[ $(cat /etc/debian_version | cut -d. -f1) -lt 12 ]]; then
    log_error "Скрипт предназначен только для Debian 12 (Bookworm)"
    exit 1
fi

log_info "Начало установки Zabbix на $(hostname)"

###############################################################################
# 1. НАСТРОЙКА РЕПОЗИТОРИЕВ YANDEX
###############################################################################
log_info "Настройка репозиториев Yandex..."

# Бэкап текущего sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%F-%H%M)

# Создание нового sources.list с зеркалом Яндекса
cat > /etc/apt/sources.list << EOF
deb https://mirror.yandex.ru/debian bookworm main contrib non-free non-free-firmware
deb https://mirror.yandex.ru/debian bookworm-updates main contrib non-free non-free-firmware
deb https://mirror.yandex.ru/debian bookworm-backports main contrib non-free non-free-firmware
deb https://mirror.yandex.ru/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

log_info "Обновление индексов пакетов..."
apt-get update -qq

###############################################################################
# 2. УСТАНОВКА ПАКЕТОВ
###############################################################################
log_info "Установка необходимых пакетов..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-agent \
    mariadb-server \
    mariadb-client \
    apache2 \
    libapache2-mod-php \
    php-mysql \
    php-gd \
    php-xml \
    php-mbstring \
    php-bcmath \
    php-ldap \
    wget \
    curl \
    gnupg2

###############################################################################
# 3. НАСТРОЙКА БАЗЫ ДАННЫХ
###############################################################################
log_info "Настройка MariaDB..."

# Запуск MariaDB
systemctl enable --now mariadb

# Создание БД и пользователя
mysql -u root << EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

log_info "Импорт схемы Zabbix в БД..."

# Импорт схемы (пакеты Debian содержат сжатые SQL файлы)
zcat /usr/share/zabbix-sql-scripts/mysql/schema.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
zcat /usr/share/zabbix-sql-scripts/mysql/images.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
zcat /usr/share/zabbix-sql-scripts/mysql/data.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}

###############################################################################
# 4. НАСТРОЙКА ZABBIX SERVER
###############################################################################
log_info "Настройка zabbix_server.conf..."

# Резервная копия конфига
cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.bak

# Настройка параметров БД и обход проверки версии MariaDB
sed -i "s/^# DBName=/DBName=${DB_NAME}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBUser=/DBUser=${DB_USER}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPassword=/DBPassword=${DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf

# Добавление параметра для поддержки новой версии MariaDB (критично для Debian 12)
if ! grep -q "AllowUnsupportedDBVersions" /etc/zabbix/zabbix_server.conf; then
    echo "AllowUnsupportedDBVersions=1" >> /etc/zabbix/zabbix_server.conf
fi

###############################################################################
# 5. НАСТРОЙКА PHP ФРОНТЕНДА
###############################################################################
log_info "Настройка PHP (Timezone: ${TIMEZONE})..."

# Настройка таймзоны PHP для CLI
sed -i "s|^;date.timezone =|date.timezone = ${TIMEZONE}|" /etc/php/8.2/apache2/php.ini
sed -i "s|^date.timezone =.*|date.timezone = ${TIMEZONE}|" /etc/php/8.2/apache2/php.ini

# Настройка параметров PHP для Zabbix
PHP_INI="/etc/php/8.2/apache2/php.ini"
sed -i "s/^max_execution_time = .*/max_execution_time = 300/" $PHP_INI
sed -i "s/^memory_limit = .*/memory_limit = 128M/" $PHP_INI
sed -i "s/^post_max_size = .*/post_max_size = 16M/" $PHP_INI
sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 2M/" $PHP_INI
sed -i "s/^max_input_time = .*/max_input_time = 300/" $PHP_INI
sed -i "s/^max_input_vars = .*/max_input_vars = 10000/" $PHP_INI

###############################################################################
# 6. НАСТРОЙКА APACHE VIRTUALHOST
###############################################################################
log_info "Настройка Apache VirtualHost для ${ZABBIX_HOSTNAME}..."

# Создание конфига виртуального хоста
cat > /etc/apache2/sites-available/zabbix.conf << EOF
<VirtualHost *:80>
    ServerName ${ZABBIX_HOSTNAME}

    DocumentRoot /usr/share/zabbix

    <Directory /usr/share/zabbix>
        Options FollowSymLinks
        AllowOverride None
        Require all granted

        <IfModule mod_php.c>
            php_value max_execution_time 300
            php_value memory_limit 128M
            php_value post_max_size 16M
            php_value upload_max_filesize 2M
            php_value max_input_time 300
            php_value max_input_vars 10000
            php_value date.timezone ${TIMEZONE}
        </IfModule>
    </Directory>

    <Directory /usr/share/zabbix/conf>
        Require all denied
    </Directory>
    <Directory /usr/share/zabbix/app>
        Require all denied
    </Directory>
    <Directory /usr/share/zabbix/include>
        Require all denied
    </Directory>
    <Directory /usr/share/zabbix/local>
        Require all denied
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/zabbix-error.log
    CustomLog \${APACHE_LOG_DIR}/zabbix-access.log combined
</VirtualHost>
EOF

# Включение сайта и модулей
a2ensite zabbix.conf
a2enmod php8.2
systemctl reload apache2

###############################################################################
# 7. НАСТРОЙКА ZABBIX AGENT
###############################################################################
log_info "Настройка Zabbix Agent..."

cp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf.bak

cat > /etc/zabbix/zabbix_agentd.conf << EOF
PidFile=/var/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=0
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=${ZABBIX_HOSTNAME}
Include=/etc/zabbix/zabbix_agentd.d/*.conf
EOF

###############################################################################
# 8. ЗАПУСК СЛУЖБ
###############################################################################
log_info "Запуск служб Zabbix..."

systemctl enable --now zabbix-server
systemctl enable --now zabbix-agent
systemctl restart apache2

# Ожидание запуска сервера
log_info "Ожидание запуска Zabbix Server (до 30 сек)..."
for i in {1..30}; do
    if systemctl is-active --quiet zabbix-server; then
        log_info "Zabbix Server запущен успешно!"
        break
    fi
    sleep 1
done

if ! systemctl is-active --quiet zabbix-server; then
    log_error "Zabbix Server не запустился! Проверьте логи: /var/log/zabbix/zabbix_server.log"
    exit 1
fi

###############################################################################
# 9. СБРОС ПАРОЛЯ ADMIN
###############################################################################
log_info "Сброс пароля пользователя Admin..."

mysql -u root ${DB_NAME} << EOF
UPDATE users SET passwd = MD5('${ADMIN_PASSWORD}'), attempt_failed = 0, attempt_ip = '', attempt_clock = 0 WHERE username = 'Admin';
EOF

###############################################################################
# 10. УБОРКА РЕПОЗИТОРИЕВ YANDEX (ОПЦИОНАЛЬНО)
###############################################################################
# Мы оставляем репозитории Яндекса, так как они нужны для будущих обновлений.
# Если вы хотите вернуться на официальные репозитории Debian, раскомментируйте код ниже:

# log_info "Восстановление оригинальных репозиториев..."
# mv /etc/apt/sources.list.bak.* /etc/apt/sources.list
# apt-get update -qq

###############################################################################
# ЗАВЕРШЕНИЕ
###############################################################################
echo ""
echo "========================================================================"
echo -e "${GREEN}✓ Установка Zabbix завершена успешно!${NC}"
echo "========================================================================"
echo ""
echo " Доступ к веб-интерфейсу:"
echo "   URL:      http://${ZABBIX_HOSTNAME}/"
echo "   Логин:    Admin"
echo "   Пароль:   ${ADMIN_PASSWORD}"
echo ""
echo "⚠️  ВАЖНО: Смените пароль после первого входа!"
echo ""
echo "📁 Основные конфиги:"
echo "   Server:   /etc/zabbix/zabbix_server.conf"
echo "   Agent:    /etc/zabbix/zabbix_agentd.conf"
echo "   Apache:   /etc/apache2/sites-available/zabbix.conf"
echo ""
echo "📋 Логи:"
echo "   Server:   /var/log/zabbix/zabbix_server.log"
echo "   Agent:    /var/log/zabbix/zabbix_agentd.log"
echo "   Apache:   /var/log/apache2/zabbix-error.log"
echo ""
echo "========================================================================"