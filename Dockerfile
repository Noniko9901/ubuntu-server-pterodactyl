FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    USER=container \
    HOME=/home/container

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates dropbear-bin openssh-client passwd \
 && rm -rf /var/lib/apt/lists/* \
 && if ! getent passwd container >/dev/null; then \
      if getent passwd 1000 >/dev/null; then \
        EXISTING_USER="$(getent passwd 1000 | cut -d: -f1)"; \
        usermod -l container "$EXISTING_USER"; \
      else \
        useradd -u 1000 -M -d /home/container -s /bin/bash container; \
      fi; \
    fi \
 && if ! getent group container >/dev/null; then \
      if getent group 1000 >/dev/null; then \
        EXISTING_GROUP="$(getent group 1000 | cut -d: -f1)"; \
        groupmod -n container "$EXISTING_GROUP"; \
      else \
        groupadd -g 1000 container; \
      fi; \
    fi \
 && usermod -g container -d /home/container -s /bin/bash container \
 && mkdir -p /home/container/.ssh \
 && chown -R container:container /home/container \
 && chmod 700 /home/container/.ssh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

WORKDIR /home/container
CMD ["/usr/local/bin/entrypoint.sh"]
