# nginx-proxy-manager_install_script
Based on https://github.com/jc21/nginx-proxy-manager

This script, install docker, docker-compose and its dependencies , deploy npm and mariadb containers.

## Usage

- You need to have docker-compose installed, script will ask you to install it if not already.
- Set execution right to deploy.sh
- While script execution, prompt passwords and installation path when required (take care to remember them !)

## How it working ?

- Retrieve passwords and installation path prompted by user

- Update and upgrade packages if user want it

- Check if docker-compose is installed (with pip3)
  - If not installed, install dependencies for common docker and docker-compose installation (python3 / python3-pip)
  - Install docker and docker-compose with official [script](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)
  
- Copy the docker-compose sample file to an production file and set your variables on it before deploy containers.

- Script will create somes directories for NPM application and database in **__$YOUR_INSTALLATION_PATH/npm-reverse-proxy__**

- Move docker-compose production file to **__$YOUR_INSTALLATION_PATH/npm-reverse-proxy__** (you will need it to for upgrading)

## Upgrade

- Do below command in **__$YOUR_INSTALLATION_PATH/npm-reverse-proxy__**
```
docker-compose pull
docker-compose up -d
```
