#!/bin/bash
###############################################################################
# Скрипт установки Zabbix 6.0 на Debian 12
# Конфигурация zabbix_server.conf - ТОЛЬКО необходимые правки
###############################################################################

set -e

# === КОНФИГУРАЦИЯ ===
DB_PASSWORD="P@ssw0rd"
DB_NAME="zabbix"
DB_USER="zabbix"
ZABBIX_HOSTNAME="mon.au-team.irpo"
TIMEZONE="Asia/Yekaterinburg"
ADMIN_PASSWORD="P@ssw0rd"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

[[ $EUID -ne 0 ]] && { log_error "Запуск от root!"; exit 1; }

log_info "Начало установки Zabbix на $(hostname)"

###############################################################################
# 1. РЕПОЗИТОРИИ YANDEX
###############################################################################
log_info "Настройка репозиториев..."
cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%F-%H%M)
cat > /etc/apt/sources.list << 'EOF'
deb https://mirror.yandex.ru/debian bookworm main contrib non-free non-free-firmware
deb https://mirror.yandex.ru/debian bookworm-updates main contrib non-free non-free-firmware
deb https://mirror.yandex.ru/debian bookworm-backports main contrib non-free non-free-firmware
deb https://mirror.yandex.ru/debian-security bookworm-security main contrib non-free non-free-firmware
EOF
apt-get update -qq

###############################################################################
# 2. УСТАНОВКА ПАКЕТОВ
###############################################################################
log_info "Установка пакетов..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zabbix-server-mysql zabbix-frontend-php zabbix-agent \
    mariadb-server mariadb-client apache2 libapache2-mod-php \
    php-mysql php-gd php-xml php-mbstring php-bcmath php-ldap wget curl gnupg2

###############################################################################
# 3. БАЗА ДАННЫХ
###############################################################################
log_info "Настройка MariaDB..."
systemctl enable --now mariadb
for i in {1..30}; do
    mysql -u root -e "SELECT 1;" &>/dev/null && break || sleep 1
done

mysql -u root << EOF
DROP DATABASE IF EXISTS ${DB_NAME};
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
DROP USER IF EXISTS '${DB_USER}'@'localhost';
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Импорт схемы
if [ -d "/usr/share/zabbix-sql-scripts/mysql" ]; then
    SQL_DIR="/usr/share/zabbix-sql-scripts/mysql"
else
    SQL_DIR="/usr/share/zabbix-server-mysql"
fi
zcat ${SQL_DIR}/schema.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
[ -f "${SQL_DIR}/images.sql.gz" ] && zcat ${SQL_DIR}/images.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}
[ -f "${SQL_DIR}/data.sql.gz" ] && zcat ${SQL_DIR}/data.sql.gz | mysql -u ${DB_USER} -p"${DB_PASSWORD}" ${DB_NAME}

###############################################################################
# 4. НАСТРОЙКА zabbix_server.conf (МИНИМАЛЬНЫЕ ПРАВКИ!)
###############################################################################
log_info "Настройка zabbix_server.conf..."

CONF="/etc/zabbix/zabbix_server.conf"

# Правим ТОЛЬКО нужные строки, не трогая остальное:
# 1. Параметры БД (раскомментируем и ставим значения)
sed -i "s|^#*DBName=.*|DBName=${DB_NAME}|" "$CONF"
sed -i "s|^#*DBUser=.*|DBUser=${DB_USER}|" "$CONF"
sed -i "s|^#*DBPassword=.*|DBPassword=${DB_PASSWORD}|" "$CONF"

# 2. LogFile
sed -i "s|^#*LogFile=.*|LogFile=/var/log/zabbix-server/zabbix_server.log|" "$CONF"

# 3. PidFile
sed -i "s|^#*PidFile=.*|PidFile=/run/zabbix/zabbix_server.pid|" "$CONF"

# 4. КРИТИЧНО: AllowUnsupportedDBVersions=1 В САМЫЙ КОНЕЦ файла
echo "AllowUnsupportedDBVersions=1" >> "$CONF"

# Проверка
if tail -1 "$CONF" | grep -q "AllowUnsupportedDBVersions=1"; then
    log_info "✓ Конфиг настроен"
else
    log_error "✗ Ошибка настройки конфига"
    exit 1
fi

chown root:zabbix "$CONF"
chmod 640 "$CONF"

###############################################################################
# 5. PHP и Apache
###############################################################################
log_info "Настройка PHP и Apache..."
PHP_INI="/etc/php/8.2/apache2/php.ini"
[ -f "$PHP_INI" ] && sed -i "s|^;date.timezone =|date.timezone = ${TIMEZONE}|" "$PHP_INI"

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
a2ensite zabbix.conf 2>/dev/null || true
systemctl reload apache2

###############################################################################
# 6. Zabbix Agent
###############################################################################


###############################################################################
# 7. ЗАПУСК
###############################################################################
log_info "Запуск служб..."
systemctl daemon-reload
systemctl enable --now zabbix-server zabbix-agent
systemctl restart apache2

for i in {1..30}; do
    systemctl is-active --quiet zabbix-server && { log_info "✓ Server запущен"; break; }
    sleep 1
done

if ! systemctl is-active --quiet zabbix-server; then
    log_error "✗ Server не запустился! Лог:"
    tail -20 /var/log/zabbix/zabbix_server.log 2>/dev/null || echo "Лог не найден"
    exit 1
fi

###############################################################################
# 8. ПАРОЛЬ ADMIN
###############################################################################
mysql -u root ${DB_NAME} -e "DELETE FROM users WHERE username='Admin'; INSERT INTO users (userid,username,passwd,name,surname,url,autologin,autologout,lang,refresh,type,theme,failed_attempts,login_attempts) VALUES ('1','Admin',MD5('${ADMIN_PASSWORD}'),'Zabbix','Administrator','',0,900,'en_US','30s',3,'darkblue',0,0);"

###############################################################################
# ФИНАЛ
###############################################################################
echo ""
echo "============================================================"
echo -e "${GREEN}✓ Zabbix установлен!${NC}"
echo "============================================================"
echo "URL:      http://${ZABBIX_HOSTNAME}/"
echo "Логин:    Admin"
echo "Пароль:   ${ADMIN_PASSWORD}"
echo "⚠️ Смените пароль после входа!"
echo "============================================================"