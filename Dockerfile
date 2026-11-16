FROM alpine:3.23

RUN apk add --no-cache bash curl ca-certificates tar xz gzip coreutils shadow iproute2 procps
ARG PROOT_VERSION=5.4.0
RUN ARCH="$(uname -m)" \
 && case "$ARCH" in x86_64) PROOT_ARCH= x86_64 ;; aarch64) PROOT_ARCH= aarch64 ;; *) echo "Unsupported architecture: $ARCH"; exit 1 ;; esac \
 && curl -fL "https://github.com/ysdragon/proot-static/releases/download/v${PROOT_VERSION}/proot-${PROOT_ARCH}-static" -o /usr/local/bin/proot \
 && chmod 0755 /usr/local/bin/proot

RUN adduser -D -h /home/container -s /bin/sh container
USER container
ENV HOME=/home/container USER=container
WORKDIR /home/container

COPY --chown=container:container entrypoint.sh /entrypoint.sh
COPY --chown=container:container install-ubuntu.sh /install-ubuntu.sh
RUN chmod 0755 /entrypoint.sh /install-ubuntu.sh

CMD ["/bin/sh", "/entrypoint.sh"]
