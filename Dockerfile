FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    USER=container \
    HOME=/home/container

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates dropbear-bin openssh-client passwd \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --home-dir /home/container --shell /bin/bash --uid 1000 container \
 && mkdir -p /home/container/.ssh \
 && chown -R container:container /home/container \
 && chmod 700 /home/container/.ssh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR /home/container
CMD ["/usr/local/bin/entrypoint.sh"]
