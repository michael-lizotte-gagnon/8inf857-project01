FROM docker.io/library/alpine:3.22

RUN apk add --no-cache nmap

ENTRYPOINT ["nmap"]
