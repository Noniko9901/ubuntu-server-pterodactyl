
FROM alpine:3.24

# Enable Alpine community repository
RUN echo "https://dl-cdn.alpinelinux.org/alpine/v3.24/main" > /etc/apk/repositories \
    && echo "https://dl-cdn.alpinelinux.org/alpine/v3.24/community" >> /etc/apk/repositories

# Install required packages
RUN apk update && apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    tar \
    xz \
    gzip \
    coreutils \
    shadow \
    iproute2 \
    procps \
    proot

# Verify PRoot installation
RUN proot --version

# Create Pterodactyl container user
RUN adduser -D -h /home/container -s /bin/sh container

USER container

ENV HOME=/home/container
ENV USER=container

WORKDIR /home/container

# Copy startup scripts
COPY --chown=container:container entrypoint.sh /entrypoint.sh
COPY --chown=container:container install-ubuntu.sh /install-ubuntu.sh

RUN chmod 0755 /entrypoint.sh /install-ubuntu.sh

CMD ["/bin/sh", "/entrypoint.sh"]
