FROM docker.io/library/alpine:3.22

RUN apk add --no-cache mariadb mariadb-client openssh-server \
    && mkdir -p /run/mysqld /var/lib/mysql /run/sshd

COPY snort-target-entrypoint.sh /usr/local/bin/snort-target-entrypoint
RUN chmod +x /usr/local/bin/snort-target-entrypoint

EXPOSE 22 3306

ENTRYPOINT ["/usr/local/bin/snort-target-entrypoint"]
