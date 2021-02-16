#!/bin/bash

function init ()
{
  #SET DATABASE PASSWORD
  read -s -e -p "Please, provide a root password for database: " dbrootpasswd
  echo -e "\n"
  read -s -e -p "Please, provide a password for user of npm database: " dbnpmpasswd
  echo -e "\n"

  #SET CONTAINER VOLUMES INSTALLATION PATH
  read -e -p "Please, provide an installation absolute path for volumes: " volpath

  #CHECK IF VOLUME PATH EXIST
  if [ -d $volpath ];then
    echo "directory "$volpath" already exist"
  else
    echo "creating "$volpath" directory"
    mkdir -p $volpath/npm-reverse-proxy
  fi
}

function update ()
{
  #SECURITY AND UPDATE
  apt update --quiet && apt install gnupg2 software-properties-common --quiet -y && apt upgrade --quiet -y && apt install unattended-upgrades --quiet -y
}

function docker ()
{
  #BASIC DEPENDENCIES
  apt install git curl apt-transport-https ca-certificates libffi-dev libssl-dev python3 python3-pip --quiet -y
  apt-get remove python-configparser

  # DOCKER-CE AND DOCKER-COMPOSE INSTALLATION
  curl -sSL https://get.docker.com | sh
  pip3 install docker-compose
}

function deploy()
{

  #SETUP
  cp docker-compose.yaml.sample docker-compose.yaml
  sed -i 's|instdir|'$volpath'|g' docker-compose.yaml
  sed -i "s/rootpasswd/$dbrootpasswd/g" docker-compose.yaml
  sed -i "s/passwd/$dbnpmpasswd/g" docker-compose.yaml

  #DEPLOY CONTAINER
  docker-compose up -d

  #CLEAN DOCKER-COMPOSE FROM REPO AND MOVE IT TO INSTALLATION PATH
  mv docker-compose.yaml $volpath/npm-reverse-proxy/docker-compose.yaml

  echo "Your instance is deployed on http://YOUR_IP_ADRESS:81"
  echo "default login are : admin@example.com / changeme"
}

#INIT SCRIPT WITH USER PARAMETERS
init

#UPDATE PACKAGES
while true
do
  read -r -p "Do you want to update and upgrade packages ? [Yes/No]" input
  case $input in [yY][eE][sS]|[yY])
    update
    break
    ;;
  [nN][oO]|[nN])
    break
    ;;
  *)
    echo "Please answer yes or no.."
    ;;
  esac
done

#CHECK DOCKER INSTALLATION
dcis=$(pip3 list 2>/dev/null | grep docker-compose | tail -n1 | awk {print'$1'})
if [[ $dcis = "docker-compose" ]];then
  echo "docker-compose is installed"
else
  while true
  do
    read -r -p "docker-compose is not installed, do you want install it with this script ? [Yes/No]" input
    case $input in [yY][eE][sS]|[yY])
      docker
      break
      ;;
    [nN][oO]|[nN])
      echo "you cannot run this script without docker-compose, please install it manually or with this script."
      exit
      break
      ;;
    *)
      echo "Please answer yes or no.."
      ;;
    esac
  done
fi
#DEPLOY NPM
deploy
