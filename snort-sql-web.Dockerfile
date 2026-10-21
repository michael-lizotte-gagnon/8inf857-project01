FROM docker.io/library/alpine:3.22

RUN apk add --no-cache mariadb-client nodejs

COPY scripts/snort-sql-obfuscation-web.js /usr/local/bin/snort-sql-obfuscation-web.js

EXPOSE 80

CMD ["node", "/usr/local/bin/snort-sql-obfuscation-web.js"]
