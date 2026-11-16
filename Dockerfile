
FROM alpine:3.23

# Install required packages
RUN apk add --no-cache \
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

# Create Pterodactyl container user
RUN adduser -D -h /home/container -s /bin/sh container

# Set working environment
USER container

ENV HOME=/home/container
ENV USER=container

WORKDIR /home/container

# Copy startup and Ubuntu installation scripts
COPY --chown=container:container entrypoint.sh /entrypoint.sh
COPY --chown=container:container install-ubuntu.sh /install-ubuntu.sh

# Set executable permissions
RUN chmod 0755 /entrypoint.sh /install-ubuntu.sh

# Start container
CMD ["/bin/sh", "/entrypoint.sh"]
