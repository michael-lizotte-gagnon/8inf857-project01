FROM docker.io/vimagick/snort3:latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends iproute2 \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["snort"]
CMD ["--help"]