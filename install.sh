#!/usr/bin/env bash

set -Eeuo pipefail

readonly PROJECT_NAME="nginx-proxy-manager"
readonly PROJECT_DIRECTORY_NAME="npm-reverse-proxy"
readonly SCRIPT_DIRECTORY="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

COMPOSE_COMMAND=()

error() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

confirm() {
  local prompt="$1"
  local response

  while true; do
    read -r -p "$prompt [y/N] " response
    case "$response" in
      [yY]|[yY][eE][sS]) return 0 ;;
      ""|[nN]|[nN][oO]) return 1 ;;
      *) printf 'Please answer yes or no.\n' ;;
    esac
  done
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    error "Run this installer as root, for example: sudo bash install.sh"
  fi
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_COMMAND=(docker compose)
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_COMMAND=(docker-compose)
  else
    return 1
  fi
}

configure_docker_repository() {
  . /etc/os-release
  [[ "$ID" = "ubuntu" ]] || error "Automatic Docker installation is supported on Ubuntu only. Install Docker and Docker Compose manually, then run this script again."

  apt-get update -q
  apt-get install -qy ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  . /etc/os-release
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
    "$(dpkg --print-architecture)" "$VERSION_CODENAME" > /etc/apt/sources.list.d/docker.list
}

install_docker() {
  printf 'Installing Docker Engine and the Docker Compose plugin...\n'
  configure_docker_repository
  apt-get update -q
  apt-get install -qy docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_compose_plugin() {
  printf 'Installing the Docker Compose plugin...\n'
  configure_docker_repository
  apt-get update -q
  apt-get install -qy docker-compose-plugin
}

ensure_docker_running() {
  docker info >/dev/null 2>&1 || error "Docker is installed but its daemon is not available. Start Docker and run the installer again."
}

is_port_available() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ! ss -H -ltn "sport = :${port}" 2>/dev/null | grep -q .
  elif command -v netstat >/dev/null 2>&1; then
    ! netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$"
  else
    printf 'Warning: Cannot check whether port %s is already in use.\n' "$port" >&2
    return 0
  fi
}

prompt_available_port() {
  local label="$1"
  local default_port="$2"
  local port

  while true; do
    read -r -p "${label} host port [${default_port}]: " port
    port="${port:-$default_port}"

    [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )) || {
      printf 'Enter a port number between 1 and 65535.\n'
      continue
    }

    if is_port_available "$port"; then
      printf '%s' "$port"
      return 0
    fi

    printf 'Port %s is already in use. Choose a different host port.\n' "$port"
  done
}

prompt_configuration() {
  local default_directory

  read -r -s -p "MariaDB root password: " DB_ROOT_PASSWORD
  printf '\n'
  [[ -n "$DB_ROOT_PASSWORD" ]] || error "The MariaDB root password cannot be empty."

  read -r -s -p "Nginx Proxy Manager database password: " DB_NPM_PASSWORD
  printf '\n'
  [[ -n "$DB_NPM_PASSWORD" ]] || error "The Nginx Proxy Manager database password cannot be empty."

  default_directory="/opt/${PROJECT_DIRECTORY_NAME}"
  read -r -e -p "Installation directory [${default_directory}]: " INSTALL_DIRECTORY
  INSTALL_DIRECTORY="${INSTALL_DIRECTORY:-$default_directory}"

  [[ "$INSTALL_DIRECTORY" = /* ]] || error "The installation directory must be an absolute path."
  INSTALL_DIRECTORY="${INSTALL_DIRECTORY%/}"

  printf '\nSelect host ports for Nginx Proxy Manager. Ports already used by cPanel, CyberPanel, or another web server must use different values.\n'
  NPM_HTTP_PORT="$(prompt_available_port "HTTP" 80)"
  NPM_HTTPS_PORT="$(prompt_available_port "HTTPS" 443)"
  NPM_ADMIN_PORT="$(prompt_available_port "Admin UI" 81)"

  [[ "$NPM_HTTP_PORT" != "$NPM_HTTPS_PORT" && "$NPM_HTTP_PORT" != "$NPM_ADMIN_PORT" && "$NPM_HTTPS_PORT" != "$NPM_ADMIN_PORT" ]] || error "HTTP, HTTPS, and Admin UI ports must be different."
}

write_environment_file() {
  local escaped_root_password escaped_npm_password

  escaped_root_password="${DB_ROOT_PASSWORD//\\/\\\\}"
  escaped_root_password="${escaped_root_password//\'/\\\'}"
  escaped_npm_password="${DB_NPM_PASSWORD//\\/\\\\}"
  escaped_npm_password="${escaped_npm_password//\'/\\\'}"

  umask 077
  cat > "${INSTALL_DIRECTORY}/.env" <<EOF
NPM_DATA_PATH='${INSTALL_DIRECTORY}'
DB_ROOT_PASSWORD='${escaped_root_password}'
DB_NPM_PASSWORD='${escaped_npm_password}'
NPM_HTTP_PORT='${NPM_HTTP_PORT}'
NPM_HTTPS_PORT='${NPM_HTTPS_PORT}'
NPM_ADMIN_PORT='${NPM_ADMIN_PORT}'
EOF
}

deploy() {
  if docker ps -a --format '{{.Names}}' | grep -Eq '^(reverse-proxy-app|reverse-proxy-db)$'; then
    error "A Nginx Proxy Manager container name is already in use. Remove or rename the existing deployment before continuing."
  fi

  [[ ! -e "${INSTALL_DIRECTORY}/compose.yaml" ]] || error "${INSTALL_DIRECTORY}/compose.yaml already exists. Use its Docker Compose commands to manage the existing deployment."
  install -d -m 0755 "${INSTALL_DIRECTORY}"
  install -d -m 0755 "${INSTALL_DIRECTORY}/data" "${INSTALL_DIRECTORY}/letsencrypt" "${INSTALL_DIRECTORY}/data/mysql"
  install -m 0644 "${SCRIPT_DIRECTORY}/docker-compose.yaml.sample" "${INSTALL_DIRECTORY}/compose.yaml"
  write_environment_file

  "${COMPOSE_COMMAND[@]}" --project-name "$PROJECT_NAME" --project-directory "$INSTALL_DIRECTORY" -f "${INSTALL_DIRECTORY}/compose.yaml" up -d

  printf '\nDeployment complete. Open http://YOUR_SERVER_IP:81\n'
  printf 'Default login: admin@example.com / changeme\n'
  printf 'Deployment files: %s\n' "$INSTALL_DIRECTORY"
}

main() {
  require_root

  if command -v docker >/dev/null 2>&1; then
    printf 'Using the existing Docker installation.\n'
    ensure_docker_running
  else
    command -v apt-get >/dev/null 2>&1 || error "Docker is not installed. Automatic installation requires Ubuntu with apt-get."

    if confirm "Update installed system packages before deployment?"; then
      apt-get update -q
      apt-get upgrade -qy
    fi

    confirm "Docker is not available. Install Docker Engine now?" || error "Docker and Docker Compose are required to continue."
    install_docker
    ensure_docker_running
  fi

  if ! detect_compose; then
    command -v apt-get >/dev/null 2>&1 || error "Docker Compose is not installed. Install Docker Compose v2 or docker-compose, then run this script again."
    confirm "Docker Compose is not available. Install the Compose plugin now?" || error "Docker Compose is required to continue."
    install_compose_plugin
    detect_compose || error "Docker Compose installation did not complete successfully."
  fi

  prompt_configuration
  deploy
}

main "$@"
