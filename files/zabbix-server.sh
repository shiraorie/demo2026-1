#!/bin/bash
###############################################################################
# Скрипт автоматической установки Zabbix 6.0 на Debian 12
# ИСПРАВЛЕННАЯ ВЕРСИЯ
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

# Ожидание готовности MariaDB
log_info "Ожидание готовности MariaDB..."
for i in {1..30}; do
    if mysql -u root -e "SELECT 1;" &>/dev/null; then
        log_info "MariaDB готова!"
        break
    fi
    sleep 1
done

# Удаление старой БД если существует (для повторного запуска)
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

# Поиск пути к SQL файлам
if [ -d "/usr/share/zabbix-sql-scripts/mysql" ]; then
    SQL_DIR="/usr/share/zabbix-sql-scripts/mysql"
    log_info "Найден путь к SQL: $SQL_DIR (новый формат)"
elif [ -d "/usr/share/zabbix-server-mysql" ]; then
    SQL_DIR="/usr/share/zabbix-server-mysql"
    log_info "Найден путь к SQL: $SQL_DIR (старый формат)"
else
    log_error "Не найдены SQL файлы схемы Zabbix!"
    exit 1
fi

# Проверка наличия файлов
if [ ! -f "${SQL_DIR}/schema.sql.gz" ]; then
    log_error "Файл schema.sql.gz не найден в ${SQL_DIR}"
    ls -la ${SQL_DIR}/
    exit 1
fi

# Импорт схемы
log_info "Импорт schema.sql..."
zcat ${SQL_DIR}/schema.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}

if [ $? -ne 0 ]; then
    log_error "Ошибка импорта schema.sql!"
    exit 1
fi

log_info "Импорт images.sql..."
if [ -f "${SQL_DIR}/images.sql.gz" ]; then
    zcat ${SQL_DIR}/images.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
fi

log_info "Импорт data.sql..."
if [ -f "${SQL_DIR}/data.sql.gz" ]; then
    zcat ${SQL_DIR}/data.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
fi

# Проверка импорта
TABLE_COUNT=$(mysql -u ${DB_USER} -p"${DB_PASSWORD}" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" 2>/dev/null)
if [ "$TABLE_COUNT" -lt 10 ]; then
    log_error "Импортировано слишком мало таблиц (${TABLE_COUNT}). Проверьте логи!"
    exit 1
fi

log_info "Успешно импортировано таблиц: ${TABLE_COUNT}"

###############################################################################
# 5. НАСТРОЙКА ZABBIX SERVER
###############################################################################
log_info "Настройка zabbix_server.conf..."

cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.bak

sed -i "s/^# DBName=/DBName=${DB_NAME}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBUser=/DBUser=${DB_USER}/" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPassword=/DBPassword=${DB_PASSWORD}/" /etc/zabbix/zabbix_server.conf

# Добавление параметра для поддержки новой версии MariaDB
if ! grep -q "AllowUnsupportedDBVersions" /etc/zabbix/zabbix_server.conf; then
    echo "AllowUnsupportedDBVersions=1" >> /etc/zabbix/zabbix_server.conf
fi

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
        log_info "Zabbix Server запущен успешно!"
        break
    fi
    sleep 1
done

if ! systemctl is-active --quiet zabbix-server; then
    log_error "Zabbix Server не запустился!"
    log_error "Последние строки лога:"
    tail -20 /var/log/zabbix/zabbix_server.log
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
############################################################################