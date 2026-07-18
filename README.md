# Nginx Proxy Manager Installer

A maintained Ubuntu installer for [Nginx Proxy Manager](https://github.com/NginxProxyManager/nginx-proxy-manager). It installs Docker Engine with the Docker Compose v2 plugin when needed, creates a persistent deployment directory, and starts Nginx Proxy Manager with MariaDB.

Maintained by **Mr.Server | HOSSAM ALZYOD | i@hossam.net**.

## Requirements

- A Linux server with Bash and root access (`sudo`)
- Docker Engine with either Docker Compose v2 (`docker compose`) or legacy Compose (`docker-compose`)
- Ubuntu with `apt-get` only when the script needs to install Docker or the Compose v2 plugin
- Internet access for Docker package and image downloads

The installer detects a running Docker Engine and uses it without reinstalling Docker. It checks the selected host ports before deployment.

## Install

```bash
git clone https://github.com/MrServers/nginx-proxy-manager-install-script.git
cd nginx-proxy-manager-install-script
sudo bash install.sh
```

The script can update system packages, installs Docker Engine and Docker Compose v2 when they are unavailable, and asks for:

- MariaDB root password
- Nginx Proxy Manager database password
- Deployment directory (defaults to `/opt/npm-reverse-proxy`)
- HTTP, HTTPS, and Admin UI host ports

Passwords are stored in a protected `.env` file in the deployment directory. Keep this file private and include it in your backups.

After deployment, open `http://YOUR_SERVER_IP:ADMIN_PORT` and sign in with:

```text
Email:    admin@example.com
Password: changeme
```

Change the default administrator credentials immediately.

## Hosting Panels And Existing Web Servers

This installer can run on servers with cPanel, CyberPanel, Plesk, Webmin, Apache, Nginx, OpenLiteSpeed, or another Docker deployment. It does not stop, reconfigure, or replace existing web services.

Those services normally already use ports `80` and `443`. When the installer reports that a port is occupied, choose unused alternatives such as `8080` for HTTP, `8443` for HTTPS, and `8181` for the Admin UI. Nginx Proxy Manager will then be reachable on those chosen ports.

Nginx Proxy Manager cannot serve standard HTTP/HTTPS traffic on ports `80` and `443` while a hosting panel or web server owns those ports. To use it as the public reverse proxy, move the existing web service to different ports or configure the existing web server to forward selected domains to the Nginx Proxy Manager ports. Do not expose two services on the same host port.

## Manage And Upgrade

The generated `compose.yaml` and `.env` remain in the deployment directory. To upgrade Nginx Proxy Manager later:

```bash
cd /opt/npm-reverse-proxy
sudo docker compose pull
sudo docker compose up -d
```

Useful commands:

```bash
sudo docker compose ps
sudo docker compose logs -f
sudo docker compose down
```

## Backup

Back up the full deployment directory before upgrades or server changes. It contains the Nginx Proxy Manager data, Let's Encrypt certificates, MariaDB data, Compose configuration, and protected environment file.

## Support

Created and maintained by **Mr.Server | HOSSAM ALZYOD | i@hossam.net**.

<a href="https://buymeacoffee.com/mrserver">Support Mr.Server on Buy Me a Coffee</a>


