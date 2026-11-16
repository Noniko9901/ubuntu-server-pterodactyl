# Ubuntu VPS Multi-Version Egg

Pterodactyl Egg inspired by ysdragon/Pterodactyl-VPS-Egg, limited to Ubuntu 20.04, 22.04, 24.04 and 26.04.

- Alpine container + PRoot user-space root filesystem
- Root SSH through Dropbear on Pterodactyl `SERVER_PORT`
- SSH auth modes: `key`, `password`, `both`
- Version selected through Egg variable `UBUNTU_VERSION`
- amd64 and arm64 multi-platform image build

## Import
Import `egg-ubuntu-vps-multiversion.json` in Admin > Nests > Import Egg.
The Docker image is `ghcr.io/noniko9901/ubuntu-server-pterodactyl:latest`.

## Configure
Set `UBUNTU_VERSION` to 20.04 / 22.04 / 24.04 / 26.04.
Set `SSH_AUTH_MODE` and its required password/key variables.
Assign a primary TCP allocation; Wings provides `SERVER_PORT`.

Connect: `ssh root@SERVER_IP -p SERVER_PORT`.

## Limitations and security
This is a PRoot user-space environment, not a VM: it shares the host kernel and does not provide systemd/kernel modules or full VM isolation. Root is emulated inside PRoot and must not be treated as host root. Dropbear is used; SFTP is not provided by Dropbear. Use `scp -O` or Pterodactyl file manager.
Ubuntu 20.04 standard support has ended; use Ubuntu Pro/ESM or prefer newer LTS releases.
Review/test the cloud-image URLs and image startup on your target architecture before production use. Never expose password SSH with a weak password.
