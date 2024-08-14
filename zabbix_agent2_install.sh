#!/usr/bin/env bash
#
# -------------------------------------------------------------------------------- #
# Script Name: "zabbix_agent2_install.sh"
# Description: Install docker-ce, zabbix-proxy (docker), zabbix-agent2 (host)
# Repository: https://github.com/qositoficial/zabbix_install
# Written By: Diego Romanio de Almeida
# Maintenance: Diego Romanio de Almeida
# -------------------------------------------------------------------------------- #
# Usage:
#       $ ./zabbix_agent2_install.sh full zabbix-hostname zabbix-proxyname
#       $ ./zabbix_agent2_install.sh agent2 zabbix-hostname
# -------------------------------------------------------------------------------- #
# Default params:
#       Docker Network: 172.18.0.0/29
#       Zabbix Proxy Container IP: 172.18.0.2
#       Zabbix Version: 6.0 LTS
#       Script Version: 1.0.2
# -------------------------------------------------------------------------------- #

# Set variables coming from arguments
INSTALATION_TYPE="$1"
ZABBIXHOSTNAME="$2"
ZABBIXPROXYNAME="$3"

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "  Warning: This script needs to be run as root or with superuser (sudo) permissions."
    exit 1
fi

# Check arguments and subnet
if [[ "$#" < 2 || $INSTALATION_TYPE != "full" && $INSTALATION_TYPE != "agent2" ]]; then
    echo "  Usage: ./$0 <full || agent2> <zabbix-hostname>"
    exit 1

elif [[ $INSTALATION_TYPE == "full" && "$#" -ne 3 ]]; then
    echo "  Usage: ./$0 <full || agent2> <zabbix-hostname> <zabbix-proxyname>"
    exit 1

fi

# Function to get the OS prettyname
get_codename() {
    source /etc/os-release
    echo "$PRETTY_NAME"
}
echo "  Operational System: $(get_codename)"

# Download error message function
download_error_message() {
    local type="$1"
    if [[ $type == "zabbix_repository" ]]; then
        echo "  Error: Zabbix repository download failed."
        exit 1
    elif [[ $type == "docker_start" ]]; then
        echo "  Error: Docker was not started."
    fi
}

# Function to download zabbix repository
install_zabbix_agent2() {
    # Check if the OS is Debian
    if [ -f "/etc/debian_version" ]; then
        debian_version=$(cat /etc/debian_version)

        # Check Debian version
        if [[ "$debian_version" != *"10."* && "$debian_version" != *"11."* && "$debian_version" != *"12."* ]]; then
            echo "      Info: This script only supports Debian 10, 11 and 12."
            exit 1
        # Debian 10 repository
        elif [[ "$debian_version" == *"10."* ]]; then
            echo "  Adding zabbix repository ..."
            wget -c -q -P /tmp https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-4+debian10_all.deb || download_error_message "zabbix_repository"
            dpkg -i /tmp/zabbix-release_6.0-4+debian10_all.deb >/dev/null 2>&1
            apt update >/dev/null 2>&1
        # Debian 11 repository
        elif [[ "$debian_version" == *"11."* ]]; then
            echo "  Adding zabbix repository ..."
            wget -c -q -P /tmp https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-4+debian11_all.deb || download_error_message "zabbix_repository"
            dpkg -i /tmp/zabbix-release_6.0-4+debian11_all.deb >/dev/null 2>&1
            apt update >/dev/null 2>&1
        # Debian 12 repository
        elif [[ "$debian_version" == *"12."* ]]; then
            echo "  Adding zabbix repository ..."
            wget -c -q -P /tmp https://repo.zabbix.com/zabbix/6.0/debian/pool/main/z/zabbix-release/zabbix-release_6.0-5+debian12_all.deb || download_error_message "zabbix_repository"
            dpkg -i /tmp/zabbix-release_6.0-5+debian12_all.deb >/dev/null 2>&1
            apt update >/dev/null 2>&1
        fi

        # Instalation zabbix-agent2
        echo "  Installing zabbix-agent2 ..."
        apt install -y zabbix-agent2 zabbix-agent2-plugin-* sudo >/dev/null 2>&1
        systemctl enable zabbix-agent2 >/dev/null 2>&1
        pkill -9 zabbix_agent2 >/dev/null 2>&1

    # Check if the OS is CentOS
    elif [ -f "/etc/centos-release" ]; then
        centos_version=$(cat /etc/centos-release | grep -oE "[0-9]+" | head -n1)

        # Check CentOS version
        if [ "$centos_version" != "7" ]; then
            echo "  Info: This script only support CentOS 7."
            exit 1
        else
            echo "  Adding zabbix repository ..."
            yum remove zabbix-release -y
            rpm -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/7/x86_64/zabbix-release-6.0-4.el7.noarch.rpm || download_error_message "zabbix_repository"
            yum clean all >/dev/null 2>&1
            apt update >/dev/null 2>&1
        fi

        # Instalation zabbix-agent2
        echo "  Installing zabbix-agent2 ..."
        yum install -y zabbix-agent2 zabbix-agent2-plugin-* sudo >/dev/null 2>&1
        systemctl enable zabbix-agent2 >/dev/null 2>&1
        pkill -9 zabbix_agent2 >/dev/null 2>&1

    # If it is not Debian or CentOS
    else
        echo "  Info: Unsupported OS."
        exit 1
    fi
}

# Adjust zabbix_agent2.conf function
adjust_zabbix_agent2_conf() {
    echo "  Adjusting zabbix_agent2.conf ..."
    rm -rf /etc/zabbix/zabbix_agent2.conf
    if [[ $INSTALATION_TYPE == "agent2" ]]; then
        echo "  Please enter the zabbix server address: "
        read -r ZABBIXSERVERADDRESS
    else
        ZABBIXSERVERADDRESS="127.0.0.1"
    fi
    echo "Server=$ZABBIXSERVERADDRESS
ServerActive=$ZABBIXSERVERADDRESS
ListenPort=10050
Hostname=$ZABBIXHOSTNAME
DebugLevel=3
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
Timeout=3
UnsafeUserParameters=1
Plugins.SystemRun.LogRemoteCommands=1
AllowKey=system.run[*]

Include=/etc/zabbix/zabbix_agent2.d/*.conf" >/etc/zabbix/zabbix_agent2.conf

    # Check if the line "zabbix ALL=(ALL) NOPASSWD: ALL" does not exist in the sudoers file
    if ! grep -q "zabbix\sALL=(ALL)\sNOPASSWD:\sALL" /etc/sudoers; then
        # Add the line "zabbix ALL=(ALL) NOPASSWD: ALL" just below the line "root ALL=(ALL:ALL) ALL"
        sed -i '/root\sALL=(ALL:ALL)\sALL/a zabbix ALL=(ALL) NOPASSWD: ALL' /etc/sudoers
    fi
}

install_docker_ce() {
    #Installation for Debian
    if [ -f "/etc/debian_version" ]; then
        debian_version=$(cat /etc/debian_version)
        # Remove old docker versions if any
        apt-get remove docker docker.io containerd runc -y >/dev/null 2>&1
        apt-get autoremove -y >/dev/null 2>&1

        # Update debian, install necessary packages and add docker repository key
        apt-get update >/dev/null 2>&1
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release >/dev/null 2>&1
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg >/dev/null 2>&1

        # Debian 10 repository
        if [[ "$debian_version" == *"10."* ]]; then
            echo "  Adding docker repository ..."
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian buster stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1
        # Debian 11 repository
        elif [[ "$debian_version" == *"11."* ]]; then
            echo "  Adding docker repository ..."
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1
        # Debian 12 repository
        elif [[ "$debian_version" == *"12."* ]]; then
            echo "  Adding docker repository ..."
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1
        fi

        # Update debian and install docker, start and activate the docker service
        echo "  Installing docker-ce ..."
        apt-get update >/dev/null 2>&1
        apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
        systemctl enable docker >/dev/null 2>&1
        systemctl start docker >/dev/null 2>&1 || download_error_message "docker_start"
        echo "  $(docker --version)"

    # Instalation for CentOS
    elif [ -f "/etc/centos-release" ]; then
        centos_version=$(cat /etc/centos-release | grep -oE "[0-9]+" | head -n1)
        # Remove old docker versions if any
        sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine >/dev/null 2>&1

        # Check CentOS version
        if [ "$centos_version" == "7" ]; then
            echo "  Adding docker repository ..."
            ln -s /usr/share/zoneinfo/ /etc/timezone
            sudo yum install -y yum-utils >/dev/null 2>&1
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
            systemctl enable docker >/dev/null 2>&1
            systemctl start docker >/dev/null 2>&1 || download_error_message "docker_start"
            echo "  $(docker --version)"
        fi
    fi
}

create_docker_compose_yml() {
    echo "  Installing docker-compose.yml ..."
    echo "   Please enter the zabbix server address: "
    read -r ZABBIXSERVERADDRESS
    rm -rf /opt/qnoc
    mkdir -p /opt/qnoc
    echo "version: \"3\"

services:
    zabbix-proxy:
        container_name: zabbix-proxy
        hostname: zabbix-proxy
        image: zabbix/zabbix-proxy-sqlite3:alpine-6.0-latest
        restart: unless-stopped
        volumes:
            - type: bind
              source: /etc/localtime
              target: /etc/localtime:ro
            - type: bind
              source: /etc/timezone
              target: /etc/timezone:ro
        environment:
            - TZ=\"America/Sao_Paulo\"
            - ZBX_PROXYMODE=0
            - ZBX_HOSTNAME=$ZABBIXPROXYNAME
            - ZBX_LISTENPORT=10051
            - ZBX_SERVER_HOST=$ZABBIXSERVERADDRESS
            - ZBX_SERVER_PORT=10051
            - ZBX_ENABLEREMOTECOMMANDS=1
            - ZBX_LOGREMOTECOMMANDS=1
            - ZBX_DEBUGLEVEL=3
            - ZBX_HOUSEKEEPINGFREQUENCY=1
            - ZBX_MAXHOUSEKEEPERDELETE=5000
            - ZBX_STARTTRAPPERS=5
            - ZBX_CACHESIZE=64M
            - ZBX_CACHEUPDATEFREQUENCY=300
            - ZBX_HISTORYCACHESIZE=64M
            - ZBX_HISTORYINDEXCACHESIZE=16M
            - ZBX_TRENDCACHESIZE=16M
            - ZBX_VALUECACHESIZE=64M
            - ZBX_TIMEOUT=4
            - ZBX_LOGSLOWQUERIES=3000
            - ZBX_STATSALLOWEDIP=127.0.0.1,::1,$ZABBIXSERVERADDRESS
        network_mode: host
        expose:
            - 10051" >/opt/qnoc/docker-compose.yml

    # Starting zabbix-proxy container
    echo "  Starting zabbix-proxy container ..."
    cd /opt/qnoc
    docker compose up -d >/dev/null 2>&1
    usermod -aG docker zabbix
    echo "$(docker ps)"
}

case "$INSTALATION_TYPE" in
"full")
    # Install docker-ce
    install_docker_ce

    # Added docker-compose.yml
    create_docker_compose_yml

    # Install zabbix-agent2
    install_zabbix_agent2

    # Adjust zabbix_agent2.conf
    adjust_zabbix_agent2_conf

    # Restart docker
    systemctl restart docker >/dev/null 2>&1

    # Start zabbix_agent2
    systemctl start zabbix-agent2 >/dev/null 2>&1

    # Prints information
    echo "  Instalation type: $INSTALATION_TYPE"
    echo "  Hostname: $ZABBIXHOSTNAME"
    echo "  Zabbix Proxy Name: $ZABBIXPROXYNAME"
    ;;
"agent2")
    # Install zabbix-agent2
    install_zabbix_agent2

    # Adjust zabbix_agent2.conf
    adjust_zabbix_agent2_conf

    #start zabbix_agent2
    systemctl start zabbix-agent2 >/dev/null 2>&1

    # Prints information
    echo "  Instalation type: $INSTALATION_TYPE"
    echo "  Hostname: $ZABBIXHOSTNAME"
    ;;

*)
    exit 1
    ;;
esac

# Ends the script
echo "  The script has ended ..."
exit 1
