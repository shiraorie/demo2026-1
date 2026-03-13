#!/bin/bash
###############################################################################
# Скрипт автоматической установки Zabbix 6.0 на Debian 12
# Версия: 3.0 (РАБОЧАЯ - параметр в конце конфига)
###############################################################################

set -e

# === КОНФИГУРАЦИЯ ===
DB_PASSWORD="P@ssw0rd"
DB_NAME="zabbix"
DB_USER="zabbix"
ZABBIX_HOSTNAME="mon.au-team.irpo"
TIMEZONE="Asia/Yekaterinburg"
ADMIN_PASSWORD="P@ssw0rd"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен от root"
   exit 1
fi

log_info "Начало установки Zabbix на $(hostname)"

###############################################################################
# 1. НАСТРОЙКА РЕПОЗИТОРИЕВ YANDEX
###############################################################################
log_info "Настройка репозиториев Yandex..."

cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%F-%H%M)

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

systemctl enable --now mariadb

log_info "Ожидание готовности MariaDB..."
for i in {1..30}; do
    if mysql -u root -e "SELECT 1;" &>/dev/null; then
        log_info "MariaDB готова!"
        break
    fi
    sleep 1
done

mysql -u root << EOF
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
DROP USER IF EXISTS '${DB_USER}'@'localhost';
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

###############################################################################
# 4. ИМПОРТ СХЕМЫ ZABBIX
###############################################################################
log_info "Импорт схемы Zabbix в БД..."

if [ -d "/usr/share/zabbix-sql-scripts/mysql" ]; then
    SQL_DIR="/usr/share/zabbix-sql-scripts/mysql"
else
    SQL_DIR="/usr/share/zabbix-server-mysql"
fi

log_info "Импорт schema.sql..."
zcat ${SQL_DIR}/schema.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
log_info "Импорт images.sql..."
[ -f "${SQL_DIR}/images.sql.gz" ] && zcat ${SQL_DIR}/images.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
log_info "Импорт data.sql..."
[ -f "${SQL_DIR}/data.sql.gz" ] && zcat ${SQL_DIR}/data.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}

TABLE_COUNT=$(mysql -u ${DB_USER} -p"${DB_PASSWORD}" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null)
log_info "Импортировано таблиц: ${TABLE_COUNT}"

###############################################################################
# 5. НАСТРОЙКА ZABBIX SERVER (РАБОЧИЙ МЕТОД!)
###############################################################################
log_info "Настройка zabbix_server.conf..."

# НЕ перезаписываем конфиг, а редактируем существующий
# 1. Раскомментируем и устанавливаем параметры БД
sed -i "s|^#DBName=.*|DBName=${DB_NAME}|" /etc/zabbix/zabbix_server.conf
sed -i "s|^#DBUser=.*|DBUser=${DB_USER}|" /etc/zabbix/zabbix_server.conf
sed -i "s|^#DBPassword=.*|DBPassword=${DB_PASSWORD}|" /etc/zabbix/zabbix_server.conf

# 2. Если параметры без # - заменяем их значения
sed -i "s|^DBName=.*|DBName=${DB_NAME}|" /etc/zabbix/zabbix_server.conf
sed -i "s|^DBUser=.*|DBUser=${DB_USER}|" /etc/zabbix/zabbix_server.conf
sed -i "s|^DBPassword=.*|DBPassword=${DB_PASSWORD}|" /etc/zabbix/zabbix_server.conf

# 3. Устанавливаем LogFile если не задан
if ! grep -q "^LogFile=" /etc/zabbix/zabbix_server.conf; then
    sed -i "s|^#LogFile=.*|LogFile=/var/log/zabbix/zabbix_server.log|" /etc/zabbix/zabbix_server.conf
fi

# 4. КРИТИЧНО: Добавляем AllowUnsupportedDBVersions=1 В САМЫЙ КОНЕЦ файла
# Это обходит проверку версии и гарантирует применение параметра
echo "" >> /etc/zabbix/zabbix_server.conf
echo "### CUSTOM SETTINGS (added by installer) ###" >> /etc/zabbix/zabbix_server.conf
echo "AllowUnsupportedDBVersions=1" >> /etc/zabbix/zabbix_server.conf

# 5. Проверка
if tail -5 /etc/zabbix/zabbix_server.conf | grep -q "AllowUnsupportedDBVersions=1"; then
    log_info "✓ AllowUnsupportedDBVersions=1 добавлен в конец конфига"
else
    log_error "✗ Не удалось добавить параметр!"
    exit 1
fi

# 6. Права на файл
chown root:zabbix /etc/zabbix/zabbix_server.conf
chmod 640 /etc/zabbix/zabbix_server.conf

log_info "Проверка параметров БД в конфиге:"
grep -E "^(DBName|DBUser|DBPassword|AllowUnsupported)" /etc/zabbix/zabbix_server.conf

###############################################################################
# 6. НАСТРОЙКА PHP ФРОНТЕНДА
###############################################################################
log_info "Настройка PHP (Timezone: ${TIMEZONE})..."

PHP_INI="/etc/php/8.2/apache2/php.ini"
if [ -f "$PHP_INI" ]; then
    sed -i "s|^;date.timezone =|date.timezone = ${TIMEZONE}|" $PHP_INI
    sed -i "s|^date.timezone =.*|date.timezone = ${TIMEZONE}|" $PHP_INI
    sed -i "s/^max_execution_time = .*/max_execution_time = 300/" $PHP_INI
    sed -i "s/^memory_limit = .*/memory_limit = 128M/" $PHP_INI
    sed -i "s/^post_max_size = .*/post_max_size = 16M/" $PHP_INI
    sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 2M/" $PHP_INI
    sed -i "s/^max_input_time = .*/max_input_time = 300/" $PHP_INI
    sed -i "s/^max_input_vars = .*/max_input_vars = 10000/" $PHP_INI
fi

###############################################################################
# 7. НАСТРОЙКА APACHE VIRTUALHOST
###############################################################################
log_info "Настройка Apache VirtualHost для ${ZABBIX_HOSTNAME}..."

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

a2ensite zabbix.conf
a2enmod php8.2 2>/dev/null || true
systemctl reload apache2

###############################################################################
# 8. НАСТРОЙКА ZABBIX AGENT
###############################################################################
log_info "Настройка Zabbix Agent..."

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
# 9. ЗАПУСК СЛУЖБ
###############################################################################
log_info "Запуск служб Zabbix..."

systemctl daemon-reload
systemctl enable --now zabbix-server
systemctl enable --now zabbix-agent
systemctl restart apache2

log_info "Ожидание запуска Zabbix Server (до 30 сек)..."
for i in {1..30}; do
    if systemctl is-active --quiet zabbix-server; then
        log_info "✓ Zabbix Server запущен успешно!"
        break
    fi
    sleep 1
done

if ! systemctl is-active --quiet zabbix-server; then
    log_error "✗ Zabbix Server не запустился!"
    log_error "Последние 20 строк лога:"
    tail -20 /var/log/zabbix/zabbix_server.log 2>/dev/null || echo "Лог не найден"
    exit 1
fi

###############################################################################
# 10. СБРОС ПАРОЛЯ ADMIN
###############################################################################
log_info "Сброс пароля пользователя Admin..."

mysql -u root ${DB_NAME} << EOF
DELETE FROM users WHERE username = 'Admin';
INSERT INTO users (userid, username, passwd, name, surname, url, autologin, autologout, lang, refresh, type, theme, failed_attempts, login_attempts) 
VALUES ('1', 'Admin', MD5('${ADMIN_PASSWORD}'), 'Zabbix', 'Administrator', '', '0', '900', 'en_US', '30s', '3', 'darkblue', '0', '0');
EOF

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
echo "========================================================================"