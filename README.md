# Ubuntu 24.04 + SSH for Pterodactyl

This is a Pterodactyl-compatible Ubuntu 24.04 Docker image using Dropbear SSH.

## Important Pterodactyl limitation

Wings starts server containers with its configured non-root UID/GID. The Egg cannot override this per server. Therefore this package intentionally provides SSH as the unprivileged `container` account, not as root. It does not use `--privileged`, Docker socket access, or host-root escalation.

The image uses public-key SSH authentication. Password authentication is intentionally not enabled: the standard non-root Pterodactyl runtime cannot safely change/read shadow credentials as root would.

## Build and publish

The included GitHub Actions workflow publishes:
`ghcr.io/<OWNER>/<REPOSITORY>:latest`

Make the GHCR package public, or configure registry credentials in Wings.

## Egg import

Import `egg-ubuntu-24.04-dropbear.json` in Admin > Nests > Import Egg.

Set the Egg Docker image to:
`ghcr.io/<OWNER>/<REPOSITORY>:latest`

Create a server, assign its primary allocation, and set `SSH_PUBLIC_KEY` to the full public key (for example the contents of `id_ed25519.pub`). `SERVER_PORT` is supplied by Wings from the primary allocation.

Connect with:
`ssh container@SERVER_IP -p SERVER_PORT`

Dropbear does not provide an SFTP subsystem. Use the Pterodactyl file manager or SCP legacy mode if supported by your client (`scp -O`).

## Add packages

Add required packages to the Dockerfile and rebuild/push the image. Installing packages interactively with apt is not available in the standard unprivileged runtime.
