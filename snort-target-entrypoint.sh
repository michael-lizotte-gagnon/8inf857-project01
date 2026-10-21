#!/bin/sh
set -eu

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is required}"

case "${MYSQL_DATABASE}${MYSQL_USER}" in
    *[!a-zA-Z0-9_]*)
        echo "MYSQL_DATABASE and MYSQL_USER may contain only letters, digits, and underscores." >&2
        exit 1
        ;;
esac

sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}

if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db
fi

chown mysql:mysql /run/mysqld
mariadbd \
    --user=mysql \
    --datadir=/var/lib/mysql \
    --socket=/run/mysqld/mysqld.sock \
    --pid-file=/run/mysqld/mysqld.pid \
    --bind-address=0.0.0.0 \
    --skip-networking=0 \
    --skip-name-resolve &

attempt=0
until mariadb-admin --socket=/run/mysqld/mysqld.sock ping --silent; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 30 ]; then
        echo "MariaDB did not become ready within 30 seconds." >&2
        exit 1
    fi
    sleep 1
done

root_password=$(sql_escape "$MYSQL_ROOT_PASSWORD")
user=$(sql_escape "$MYSQL_USER")
password=$(sql_escape "$MYSQL_PASSWORD")
mariadb --socket=/run/mysqld/mysqld.sock -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${user}'@'%' IDENTIFIED BY '${password}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${user}'@'%';
FLUSH PRIVILEGES;
SQL

ssh-keygen -A
exec /usr/sbin/sshd -D -e
