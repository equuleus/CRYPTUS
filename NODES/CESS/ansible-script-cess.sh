#!/bin/bash
### -------------------------------------------------------------------------------------------------
# COPYRIGHT: EQUULEUS [https://github.com/equuleus]
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
# https://github.com/CESSProject/cess
# https://github.com/CESSProject/cess-node
# https://github.com/CESSProject/cess/releases
# https://rustrepo.com/repo/CESSProject-cess-rust-network-programming
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set external IP address:
declare IP=$(wget -qO- eth0.me) >/dev/null 2>&1
# declare IP=$(curl ifconfig.me) >/dev/null 2>&1
### Set home directory:
if [ "$(whoami)" == "root" ]; then
	declare HOME_PATH="/root"
else
	declare HOME_PATH="/home/$(id -un)"
fi
### Set Docker path and filename:
declare DOCKER_FILEPATH="${HOME_PATH}/.cess"
declare DOCKER_FILENAME="dockerfile.cess"
declare DOCKER_IMAGENAME="cryptus/cess"
declare DOCKER_CONTAINERNAME="cess"
if [ "$(whoami)" == "root" ]; then
	declare DOCKER_DATAPATH="/root/.cess"
else
	declare DOCKER_DATAPATH="/home/$(id -un)/.cess"
fi
### Set database path, filename and base delimiter:
declare DATABASE_FILEPATH="${HOME_PATH}"
declare DATABASE_FILENAME="cess.txt"
declare DATABASE_DELIMITER="|"
### Default script action:
declare SCRIPT_ACTION="INSTALL"
### Default node ports:
declare SCRIPT_NODE_PORT="9944"
declare SCRIPT_NODE_PROMETHEUS="9615"
declare SCRIPT_PORTS=""
### Default log style (colored or not) [true / false]:
declare SCRIPT_LOG_COLOR=true
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function LOG() {
	declare TEXT="${1}"
	declare DATE=$(date +"[%Y-%m-%d] [%H:%M:%S]")
	if [ ${SCRIPT_LOG_COLOR} == true ]; then
		echo -e "${DATE} ${TEXT}"
	else
		echo -e "${DATE} ${TEXT}" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"
	fi
	unset DATE
	unset TEXT
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function SYSTEM() {
### -------------------------------------------------------------------------------------------------
### Set DNS fail-safe server:
	echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null
#	echo "nameserver 8.8.8.8" | sudo tee /etc/resolvconf/resolv.conf.d/base >/dev/null
### -------------------------------------------------------------------------------------------------
### Install and update system packages:
	LOG "\e[34m [INFO] INSTALLING AND UPDATING SYSTEM PACKAGES...\e[39m"
	sudo apt update
	sudo apt --yes upgrade
	sudo apt --yes --no-install-recommends install curl wget sudo
#	sudo apt --yes --no-install-recommends install curl wget git sudo unzip
	LOG "\e[32m [RESULT] SYSTEM PACKAGES INSTALLED AND UPDATED SUCCESSFULLY.\e[39m"
### -------------------------------------------------------------------------------------------------
### Install "Docker":
	if ! [ -x "$(command -v docker)" ]; then
		LOG "\e[34m [INFO] INSTALLING 'DOCKER'...\e[39m"
### Install dependencies needed by the installation process:
		sudo apt --yes --no-install-recommends install apt-transport-https ca-certificates curl gnupg lsb-release
### Add Docker's repository GPG key:
		curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | sudo gpg --dearmor --yes -o "/usr/share/keyrings/docker-archive-keyring.gpg"
#		wget -qO- "https://download.docker.com/linux/ubuntu/gpg" | sudo gpg --dearmor --yes -o "/usr/share/keyrings/docker-archive-keyring.gpg"
### Add the repository to sources:
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
### Or other way to download GPG key and add repository:
#		wget --quiet --output-document=- https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#		sudo add-apt-repository --yes "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release --codename --short) stable"
### Update package lists:
		sudo apt update
### Get "Docker" version (regexp - anything except "_" after "docker-ce | " and before " | https"):
		declare VERSION=$(apt-cache madison docker-ce | grep -oPm1 "(?<=docker-ce \| )([^_]+)(?= \| https)")
### Install "Docker":
		sudo apt --yes --no-install-recommends install docker-ce="${VERSION}" docker-ce-cli="${VERSION}" containerd.io
#		sudo apt --yes --no-install-recommends install docker-ce docker-ce-cli containerd.io
		unset VERSION
### The Docker daemon runs as root. You must usually prefix Docker commands with sudo. This can get tedious if you're using Docker often. Adding yourself to the docker group will let you use Docker without sudo.
		sudo usermod --append --groups docker "${USER}"
#		sudo usermod -aG docker $USER
### Enable service start at boot:
		sudo systemctl enable docker.service
		sudo systemctl enable containerd.service
		if [ "$(sudo systemctl is-active docker)" == "active" ]; then
			LOG "\e[32m [RESULT] 'DOCKER' INSTALLED SUCCESSFULLY.\e[39m"
		else
### Or other official way to install latest "Docker" from official script:
			LOG "\e[33m [WARNING] 'DOCKER' WAS NOT INSTALLED, TRYING OTHER WAY TO INSTALL...\e[39m"
			curl -fsSL "https://get.docker.com" -o "./get-docker.sh"
			if [ -f "./get-docker.sh" ]; then
				sudo sh "./get-docker.sh"
				rm -f "./get-docker.sh"
				if [ "$(sudo systemctl is-active docker)" == "active" ]; then
					LOG "\e[32m [RESULT] 'DOCKER' INSTALLED SUCCESSFULLY.\e[39m"
				else
					LOG "\e[31m [ERROR] 'DOCKER' WAS NOT INSTALLED. CAN NOT CONTINUE.\e[39m"
					exit
				fi
			else
				LOG "\e[31m [ERROR] 'DOCKER' NOT DOWNLOADED, PLEASE INSTALL IT MANUALLY. CAN NOT CONTINUE.\e[39m"
				exit
			fi
		fi
	fi
### -------------------------------------------------------------------------------------------------
### Install "Docker Compose":
	if ! [ -x "$(command -v docker-compose)" ] || ! [ -f "/usr/local/bin/docker-compose" ]; then
### Download "https://api.github.com/repos/docker/compose/releases/latest" and select "tag_name" value from it, then cut first character "v":
		declare VERSION=$(wget --quiet --output-document=- "https://api.github.com/repos/docker/compose/releases/latest" | grep --perl-regexp --only-matching '"tag_name": "\K.*?(?=")' | sed "s/^v//")
### Or other way to do the same with "jq":
#		sudo apt --yes --no-install-recommends install wget jq
#		declare VERSION=$(wget -qO- "https://api.github.com/repos/docker/compose/releases/latest" | jq -r ".tag_name" | sed "s/^v//")
		if ! [ -z "${VERSION}" ]; then
			LOG "\e[34m [INFO] INSTALLING 'DOCKER COMPOSE'...\e[39m"
### Get system version and type, then lowercase its values, and finally download actual version for our system to "/usr/local/bin/docker-compose":
			sudo curl -SL "https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s | sed -e 's/\(.*\)/\L\1/')-$(uname -m | sed -e 's/\(.*\)/\L\1/')" -o "/usr/local/bin/docker-compose"
			if [ -f "/usr/local/bin/docker-compose" ]; then
### Set permissions:
				sudo chmod +x "/usr/local/bin/docker-compose"
### Make link:
				sudo ln -s "/usr/local/bin/docker-compose" "/usr/bin/docker-compose"
				. ${HOME}/.bash_profile
				LOG "\e[32m [RESULT] 'DOCKER COMPOSE' INSTALLED SUCCESSFULLY.\e[39m"
			else
				LOG "\e[31m [ERROR] 'DOCKER COMPOSE' NOT DOWNLOADED, PLEASE INSTALL IT MANUALLY. CAN NOT CONTINUE.\e[39m"
				exit
			fi
		else
			LOG "\e[31m [ERROR] 'DOCKER COMPOSE' ACTUAL VERSION NOT FOUND, PLEASE INSTALL IT MANUALLY. CAN NOT CONTINUE.\e[39m"
			exit
		fi
		unset VERSION
	fi
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function PORTS() {
### Get input array variable:
	declare -a PORTS="${1}"
### Open ports:
#	LOG "\e[34m [INFO] OPENING PORTS...\e[39m"
### Check if firewall service is active:
	if ! [ -z "$(sudo ufw status | grep -w \"active\")" ]; then
### Read current firewall configuration:
		declare FIREWALL_COMMAND=$(sudo ufw status | grep -v '^\s*$' | tail -n +4)
### Make a list from all lines:
		IFS=$'\n' read -rd "" -a FIREWALL_RESULT <<< "${FIREWALL_COMMAND}"
### Check all our ports:
		for FIREWALL_PORT in "${PORTS[@]}"; do
### Set variable default value:
			declare FIREWALL_RULE_FOUND=false
### Check all lines of firewall configuration:
			for FIREWALL_RULE_LINE in "${FIREWALL_RESULT[@]}"; do
### Check match our port with firewall rule line (if result is not empty):
				if ! [ -z "$(echo \"${FIREWALL_RULE_LINE}\" | grep -w \"${FIREWALL_PORT}\")" ]; then
					FIREWALL_RULE_FOUND=true
				fi
				unset FIREWALL_RULE_LINE
			done
### If we got a name of a rule, run command to remove it:
			if [ "${FIREWALL_RULE_FOUND}" == false ]; then
				LOG "\e[32m [RESULT] PORT '${FIREWALL_PORT}' SUCCESSFULLY OPENED IN FIREWALL.\e[39m"
### Add port to firewall:
				sudo ufw allow "${FIREWALL_PORT}" >/dev/null 2>&1
			else
				LOG "\e[34m [INFO] PORT '${FIREWALL_PORT}' ALREADY OPENED IN FIREWALL.\e[39m"
			fi
			unset FIREWALL_RULE_FOUND
			unset FIREWALL_PORT
		done
		unset FIREWALL_RESULT
		unset FIREWALL_COMMAND
	else
		LOG "\e[33m [WARNING] FIREWALL IS NOT IN ACTIVE STATE, CAN NOT ADD PORT(S) '${PORTS}' TO ALLOW LIST.\e[39m"
	fi
### Check if "IPTables" is installed:
	IPTABLES=$(apt list --installed 2>/dev/null | grep -w "iptables") >/dev/null 2>&1
	if ! [ -z "${IPTABLES}" ]; then
### If it is installed, - run command to add rule with our port:
		for IPTABLES_PORT in "${PORTS[@]}"; do
### Add ports to "IPTables":
# !!! Do the same as firewall...
			sudo iptables -I INPUT -p tcp --dport "${IPTABLES_PORT}" -j ACCEPT >/dev/null 2>&1
			unset IPTABLES_PORT
		done
		if [ -d "/etc/iptables" ] && [ ! -L "/etc/iptables" ]; then
			sudo iptables-save > /etc/iptables/rules.v4
			sudo ip6tables-save > /etc/iptables/rules.v6
		fi
	fi
	unset IPTABLES
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_INSTALL() {
### Get input variables:
	declare DOCKER_FILEPATH="${1}"
	declare DOCKER_FILENAME="${2}"
	declare DOCKER_IMAGENAME="${3}"
	declare DOCKER_CONTAINERNAME="${4}"
	declare DOCKER_DATAPATH="${5}"
	declare SCRIPT_NODE_PORT="${6}"
	declare SCRIPT_NODE_PROMETHEUS="${7}"
	declare SCRIPT_PORTS="${8}"
### If Docker image not found, generate it:
	if [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
#	if [ -z "$(sudo docker images 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -w ${DOCKER_IMAGENAME})" ]; then
### Set GitHub "latest" release info file:
		declare NODE_GIT="https://api.github.com/repos/cessproject/cess/releases/latest"
### Download "https://api.github.com/repos/cessproject/cess/releases/latest" and select "tag_name" value from it, then cut first character "v":
		declare VERSION=$(wget --quiet --output-document=- "${NODE_GIT}" | grep --perl-regexp --only-matching '"tag_name": "\K.*?(?=")' | sed "s/^v//")
### Or other way to do the same with "jq":
#		sudo apt --yes --no-install-recommends install jq
#		declare VERSION=$(wget -qO- "${NODE_GIT}" | jq -r ".tag_name" | sed "s/^v//")
### If we have a version, we can download node file:
		if ! [ -z "${VERSION}" ]; then
			LOG "\e[34m [INFO] 'CESS' WEB VERSION: '${VERSION}'.\e[39m"
### Create link:
			declare FILE_GIT_URL="https://github.com/cessproject/cess/releases/download/v${VERSION}/cess-node"
			LOG "\e[32m [RESULT] ACTUAL 'CESS' FILE URL FOUND ('${FILE_GIT_URL}').\e[39m"
### Trying to download:
			declare FILE_GIT_INFO=$(wget --spider "${FILE_GIT_URL}" 2>&1)
			if ! [ -z "${FILE_GIT_INFO}" ]; then
### Check content:
				declare FILE_GIT_SIZE=$(echo "${FILE_GIT_INFO}" | grep -oPm1 "(?<=Length\: )([0-9]+)(?= \()")
### If file size detected, we can continue:
				if ! [ -z "${FILE_GIT_SIZE}" ]; then
					LOG "\e[32m [RESULT] FILE SIZE '${FILE_GIT_URL}' FOUND ('${FILE_GIT_SIZE}' bytes).\e[39m"
### Check and create if not exists directory for datapath:
					if ! [ -d "${DOCKER_DATAPATH}" ]; then
						mkdir -p "${DOCKER_DATAPATH}" >/dev/null 2>&1
					fi
					declare NODE_FILENAME="cess-node"
					if [ -f "${DOCKER_FILEPATH}/${NODE_FILENAME}" ]; then
						rm -f "${DOCKER_FILEPATH}/${NODE_FILENAME}"
					fi
					LOG "\e[34m [INFO] TRYING TO DOWNLOAD FILE FROM '${FILE_GIT_URL}' TO '${DOCKER_DATAPATH}/${NODE_FILENAME}'.\e[39m"
					declare FILE_GIT_DOWNLOAD=$(wget -O "${DOCKER_DATAPATH}/${NODE_FILENAME}" "${FILE_GIT_URL}" 2>&1)
					if [ -z '$(echo "${FILE_GIT_DOWNLOAD}" | grep -w "saved \[${FILE_GIT_SIZE}/${FILE_GIT_SIZE}\]")' ]; then
						LOG "\e[31m [ERROR] CAN NOT CREATE DOCKER IMAGE '${DOCKER_IMAGENAME}', FILE '${NODE_FILENAME}' DOWNLOAD SIZE NOT MATCH ('"$(wc -c < "${DOCKER_DATAPATH}/${NODE_FILENAME}")"' of '${FILE_GIT_SIZE}' bytes). CAN NOT CONTINUE.\e[39m"
						if [ -f "${DOCKER_DATAPATH}/${NODE_FILENAME}" ]; then
							rm -f "${DOCKER_DATAPATH}/${NODE_FILENAME}"
						fi
					fi
					unset FILE_GIT_DOWNLOAD
					if [ -f "${DOCKER_DATAPATH}/${NODE_FILENAME}" ]; then
						LOG "\e[32m [RESULT] FILE '${DOCKER_DATAPATH}/${NODE_FILENAME}' SUCCESSFULLY DOWNLOADED ('${FILE_GIT_SIZE}' bytes).\e[39m"
### Removing if exists and then creating new "dockerfile":
						if [ -f "${DOCKER_FILEPATH}/${DOCKER_FILENAME}" ]; then
							rm -f "${DOCKER_FILEPATH}/${DOCKER_FILENAME}"
						fi
						echo "# Base image of system:
FROM ubuntu:20.04

# Set metadata, like author info:
LABEL creator=\"EQUULEUS\"
LABEL url=\"https://github.com/equuleus\"

# Set working (current) directory in container:
WORKDIR /root

# Copy files \"cess-node\" and \"entrypoint.sh\" to work directory (set before in \"WORKDIR\" - \"/root\"):
COPY [\"./cess-node\", \"./entrypoint.sh\", \"/root/\"]
# Grant permissions to execute for files \"cess-node\" and \"entrypoint.sh\":
RUN chmod +x \"/root/cess-node\" \"/root/entrypoint.sh\"

## To disable warning in use of \"apt-get\" [\"debconf: delaying package configuration, since apt-utils is not installed\"], anyway it's not an error:
## Update system and install new packages (\"apt-utils\" and \"wget\"):
# RUN apt-get update && apt-get --yes upgrade && apt-get --yes --no-install-recommends install \"apt-utils\" \"wget\" && rm -rf \"/var/lib/apt/lists/*\"

# Update system and install new package (\"wget\"):
RUN apt-get update && apt-get --yes upgrade && apt-get --yes --no-install-recommends install \"wget\" && rm -rf \"/var/lib/apt/lists/*\"

# Open ports \"9615\" and \"9944\":
EXPOSE \"9615\" \"9944\"

# Create volume (to mount it later):
VOLUME \"/root/.cess\"

# Set command (with arguments) wich is executed every time we run container:
ENTRYPOINT [\"/root/entrypoint.sh\"]
" > "${DOCKER_FILEPATH}/${DOCKER_FILENAME}"
						if [ -f "${DOCKER_FILEPATH}/${DOCKER_FILENAME}" ]; then
### Removing if exists and then creating new file "entrypoint.sh":
							if [ -f "${DOCKER_DATAPATH}/entrypoint.sh" ]; then
								rm -f "${DOCKER_DATAPATH}/entrypoint.sh"
							fi
### "--chain" argument for "cess-node" may be:
### "cess-testnet" (https://github.com/CESSProject/cess)
### "cess-hacknet" (https://github.com/CESSProject/cess-node)
### "C-ALPHA" (https://rustrepo.com/repo/CESSProject-cess-rust-network-programming)
							echo "#!/bin/bash
declare FILE_PATH_NODE=\"/root\"
declare FILE_NAME_NODE=\"cess-node\"
declare FILE_PATH_KEYS=\"\${FILE_PATH_NODE}\"
declare FILE_NAME_KEYS=\"secretKey.txt\"
declare FILE_PATH_TEMP=\"\${FILE_PATH_NODE}/temp\"
declare FILE_NAME_TEMP=\"cess-node\"
declare FILE_PATH_VOLUME=\"/root/.cess\"
declare VERSION=\$(wget --quiet --output-document=- \"https://api.github.com/repos/cessproject/cess/releases/latest\" | grep --perl-regexp --only-matching '\"tag_name\": \"\K.*?(?=\")' | sed \"s/^v//\")
if ! [ -z \"\${VERSION}\" ]; then
	if [ -f \"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\" ]; then
		declare FILE_LOCAL_SIZE=\$(wc -c < \"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\")
	else
		declare FILE_LOCAL_SIZE=0
	fi
	declare FILE_GIT_URL=\"https://github.com/cessproject/cess/releases/download/v\${VERSION}/cess-node\"
	declare FILE_GIT_INFO=\$(wget --spider \"\${FILE_GIT_URL}\" 2>&1)
	declare FILE_GIT_SIZE=\$(echo \"\${FILE_GIT_INFO}\" | grep -oPm1 \"(?<=Length\\: )([0-9]+)(?= \\()\")
	if [ \"\${FILE_LOCAL_SIZE}\" -eq 0 ] || [ \"\${FILE_LOCAL_SIZE}\" -ne \"\${FILE_GIT_SIZE}\" ]; then
		if [ -d \"\${FILE_PATH_TEMP}\" ]; then
			rm -rf \"\${FILE_PATH_TEMP}\"
		fi
		mkdir -p \"\${FILE_PATH_TEMP}\"
		declare FILE_UPDATE=\$(wget -O \"\${FILE_PATH_TEMP}/\${FILE_NAME_TEMP}\" \"\${FILE_GIT_URL}\" 2>&1)
		if ! [ -z '\$(echo \\\"\${FILE_GIT_DOWNLOAD}\\\" | grep -w \"saved \\[\${FILE_GIT_SIZE}/\${FILE_GIT_SIZE}\\]\")' ]; then
			if [ -f \"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\" ]; then
				rm -f \"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\"
			fi
			mv -f \"\${FILE_PATH_TEMP}/\${FILE_NAME_TEMP}\" \"\${FILE_PATH_NODE}\"
			chmod +x \"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\"
		fi
		unset FILE_UPDATE
		rm -rf \"\${FILE_PATH_TEMP}\"
	fi
	unset FILE_GIT_SIZE
	unset FILE_GIT_INFO
	unset FILE_GIT_URL
	unset FILE_LOCAL_SIZE
fi
unset VERSION
unset FILE_NAME_TEMP
unset FILE_PATH_TEMP
cd \"\${FILE_PATH_NODE}\"
mkdir -p \"\${FILE_PATH_VOLUME}/base\"
if [ -f \"\${FILE_PATH_KEYS}/\${FILE_NAME_KEYS}\" ]; then
	\"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\" key insert --base-path \"\${FILE_PATH_VOLUME}/base\" --chain \"cess-testnet\" --scheme \"sr25519\" --key-type babe --suri \"\${FILE_PATH_KEYS}/\${FILE_NAME_KEYS}\"
	\"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\" key insert --base-path \"\${FILE_PATH_VOLUME}/base\" --chain \"cess-testnet\" --scheme \"ed25519\" --key-type gran --suri \"\${FILE_PATH_KEYS}/\${FILE_NAME_KEYS}\"
	rm -f \"\${FILE_PATH_KEYS}/\${FILE_NAME_KEYS}\"
fi
\"\${FILE_PATH_NODE}/\${FILE_NAME_NODE}\" --base-path \"\${FILE_PATH_VOLUME}/base\" --chain \"cess-testnet\"
unset FILE_PATH_VOLUME
unset FILE_NAME_NODE
unset FILE_PATH_NODE
" > "${DOCKER_DATAPATH}/entrypoint.sh"
							if [ -f "${DOCKER_DATAPATH}/entrypoint.sh" ]; then
								LOG "\e[34m [INFO] DOCKER IMAGE '${DOCKER_IMAGENAME}' NOT FOUND. TRYING TO CREATE IT FROM '${DOCKER_DATAPATH}/${DOCKER_FILENAME}'...\e[39m"
								sudo docker build -t "${DOCKER_IMAGENAME}:latest" -f "${DOCKER_DATAPATH}/${DOCKER_FILENAME}" "${DOCKER_DATAPATH}"
								rm -f "${DOCKER_DATAPATH}/entrypoint.sh"
							else
								LOG "\e[31m [ERROR] CAN NOT CREATE DOCKER IMAGE '${DOCKER_IMAGENAME}', FILE '${DOCKER_DATAPATH}/entrypoint.sh' NOT FOUND. CAN NOT CONTINUE.\e[39m"
							fi
							rm -f "${DOCKER_DATAPATH}/${DOCKER_FILENAME}"
						else
							LOG "\e[31m [ERROR] CAN NOT CREATE DOCKER IMAGE '${DOCKER_IMAGENAME}', FILE '${DOCKER_FILEPATH}/${DOCKER_FILENAME}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
						fi
						rm -f "${DOCKER_DATAPATH}/${NODE_FILENAME}"
					fi
					unset NODE_FILENAME
				else
					LOG "\e[31m [ERROR] CAN NOT CREATE DOCKER IMAGE '${DOCKER_IMAGENAME}', CAN NOT GET FILE SIZE OF '${FILE_GIT_URL}'. CAN NOT CONTINUE.\e[39m"
				fi
				unset FILE_GIT_SIZE
			else
				LOG "\e[31m [ERROR] CAN NOT CREATE DOCKER IMAGE '${DOCKER_IMAGENAME}', CAN NOT GET FILE CONTENT FROM '${FILE_GIT_URL}'. CAN NOT CONTINUE.\e[39m"
			fi
			unset FILE_GIT_INFO
			unset FILE_GIT_URL
		else
			LOG "\e[31m [ERROR] CAN NOT CREATE DOCKER IMAGE '${DOCKER_IMAGENAME}', CAN NOT GET ACTUAL VERSION OF NODE FROM '${NODE_GIT}'. CAN NOT CONTINUE.\e[39m"
		fi
		unset VERSION
		unset NODE_GIT
	else
		LOG "\e[34m [INFO] DOCKER IMAGE '${DOCKER_IMAGENAME}' ALREADY EXISTS.\e[39m"
	fi
### Creating Docker container(s) based on port(s):
	if ! [ -z "${SCRIPT_PORTS}" ]; then
		IFS=',' read -r -a NODE_PORTS <<< "${SCRIPT_PORTS}"
	else
		declare -a NODE_PORTS=("${SCRIPT_NODE_PORT}")
	fi
	unset SCRIPT_PORTS
	for NODE_PORT in "${NODE_PORTS[@]}"; do
### Set prometheus exporter port:
		declare -i NODE_PROMETHEUS=(${SCRIPT_NODE_PROMETHEUS}+${NODE_PORT}-${SCRIPT_NODE_PORT})
### Check necessary ports:
		declare TEST=""
		for PORT in "$NODE_PORT" "$NODE_PROMETHEUS"; do
			if [ -z "$TEST" ]; then
				TEST=$(ss -tulpen | awk '{print $5}' | grep ":$PORT$")
				if ! [ -z "$TEST" ]; then
					LOG "\e[31m [ERROR] INSTALLATION ON PORT \"$PORT\" IS NOT POSSIBLE, PORT IS ALREADY IN USE.\e[39m"
				fi
			fi
			unset PORT
		done
		if [ -z "$TEST" ]; then
			if ! [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
				declare CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
				if [ -z "${CONTAINER}" ]; then
					LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT FOUND. TRYING TO CREATE AND START DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}'...\e[39m"
					sudo docker run -dit --restart on-failure --name "${DOCKER_CONTAINERNAME}_${NODE_PORT}" -v "${DOCKER_DATAPATH}/${NODE_PORT}:/root/.cess" -p "${NODE_PORT}:9944" -p "${NODE_PROMETHEUS}:9615" "${DOCKER_IMAGENAME}:latest" >/dev/null 2>&1
					sleep 1
					CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
					if ! [ -z "${CONTAINER}" ]; then
						LOG "\e[32m [RESULT] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' CREATED SUCCESSFULLY.\e[39m"
### Activate node (generate keys, etc):
						NODE_ACTIVATE "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}" "${DOCKER_DATAPATH}" "${NODE_PORT}" "${NODE_PROMETHEUS}"
#						sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --tail 100
#						set +m
#						timeout --kill-after 1s 10s sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --follow --tail 100
#						set -m
					else
						LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT CREATED. CAN NOT CONTINUE.\e[39m"
					fi
				else
					LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS ALREADY CREATED, AND STATUS IS: '${CONTAINER}'.\e[39m"
					LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' LOG (LAST 100 LINES):\e[39m"
					sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --tail 100
#					set +m
#					timeout --kill-after 1s 10s sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --follow --tail 100
#					set -m
### Transform status value to lowercase:
					declare STATUS=$(echo "${CONTAINER}" | sed -e 's/\(.*\)/\L\1/')
					if [ "${STATUS}" != "up" ]; then
						LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' STARTING...\e[39m"
						sudo docker container start "${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
						sleep 1
						CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
						STATUS=$(echo "${CONTAINER}" | sed -e 's/\(.*\)/\L\1/')
						if [ "${STATUS}" == "up" ]; then
							LOG "\e[32m [RESULT] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' STARTED SUCCESSFULLY.\e[39m"
						else
							LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT STARTED, AND STATUS IS: '${CONTAINER}'.\e[39m"
						fi
					fi
					unset STATUS
				fi
				unset CONTAINER
			else
				LOG "\e[31m [ERROR] DOCKER IMAGE '${DOCKER_IMAGENAME}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
			fi
		fi
		unset TEST
		unset NODE_PROMETHEUS
		unset NODE_PORT
	done
	unset NODE_PORTS
	unset SCRIPT_NODE_PROMETHEUS
	unset SCRIPT_NODE_PORT
	unset DOCKER_DATAPATH
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
	unset DOCKER_FILENAME
	unset DOCKER_FILEPATH
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_UNINSTALL () {
### Get input variables:
	declare DOCKER_IMAGENAME="${1}"
	declare DOCKER_CONTAINERNAME="${2}"
	declare SCRIPT_NODE_PORT="${3}"
	declare SCRIPT_PORTS="${4}"
	if ! [ -z "${SCRIPT_PORTS}" ]; then
		IFS=',' read -r -a NODE_PORTS <<< "${SCRIPT_PORTS}"
	else
		declare -a NODE_PORTS=("${SCRIPT_NODE_PORT}")
	fi
	unset SCRIPT_PORTS
	unset SCRIPT_NODE_PORT
### Check Docker image exists:
	if ! [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
### Check all ports:
		for NODE_PORT in "${NODE_PORTS[@]}"; do
			declare CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
			if [ -z "${CONTAINER}" ]; then
				LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT FOUND. NOTHING TO DO.\e[39m"
			else
### Transform status value to lowercase:
				declare STATUS=$(echo "${CONTAINER}" | sed -e 's/\(.*\)/\L\1/')
				if [ "${STATUS}" == "up" ]; then
					LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS RUNNING, STOPPING IT...\e[39m"
					sudo docker container stop "${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
				fi
				LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') REMOVING...\e[39m"
				sudo docker container rm --force --volumes "${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
				declare CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
				if [ -z "${CONTAINER}" ]; then
					LOG "\e[32m [RESULT] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') REMOVE SUCCESSFULL.\e[39m"
					NODE_AUTOSTART_REMOVE "${DOCKER_CONTAINERNAME}" "${NODE_PORT}"
				else
					LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') REMOVE FAILED.\e[39m"
				fi
				unset STATUS
			fi
			unset CONTAINER
			unset NODE_PORT
		done
### Check Docker image for removing:
		if [ -z "$(sudo docker ps -a --format \"{{.Image}}\" | grep \"${DOCKER_IMAGENAME}:latest\")" ]; then
			LOG "\e[34m [INFO] DOCKER CONTAINERS FOR IMAGE '${DOCKER_IMAGENAME}' NOT FOUND, REMOVING IMAGE...\e[39m"
			sudo docker image rm --force "$DOCKER_IMAGENAME" >/dev/null 2>&1
			if [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
				LOG "\e[32m [RESULT] DOCKER IMAGE '$DOCKER_IMAGENAME' REMOVE SUCCESSFULL.\e[39m"
			else
				LOG "\e[31m [ERROR] DOCKER IMAGE '$DOCKER_IMAGENAME' REMOVE FAILED.\e[39m"
			fi
		fi
	else
		LOG "\e[34m [INFO] DOCKER IMAGE '${DOCKER_IMAGENAME}' NOT FOUND. NOTHING TO DO.\e[39m"
	fi
	unset NODE_PORTS
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_RESTART() {
### Get input variables:
	declare DOCKER_IMAGENAME="${1}"
	declare DOCKER_CONTAINERNAME="${2}"
	declare SCRIPT_NODE_PORT="${3}"
	declare SCRIPT_PORTS="${4}"
	if ! [ -z "${SCRIPT_PORTS}" ]; then
		IFS=',' read -r -a NODE_PORTS <<< "${SCRIPT_PORTS}"
	else
		declare -a NODE_PORTS=("${SCRIPT_NODE_PORT}")
	fi
	unset SCRIPT_PORTS
	unset SCRIPT_NODE_PORT
### Check Docker image exists:
	if ! [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
### Check all ports:
		for NODE_PORT in "${NODE_PORTS[@]}"; do
			declare CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
			if [ -z "${CONTAINER}" ]; then
				LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
			else
### Transform status value to lowercase:
				declare STATUS=$(echo "${CONTAINER}" | sed -e 's/\(.*\)/\L\1/')
				if [ "${STATUS}" == "exited" ]; then
					LOG "\e[32m [RESULT] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS STOPPED. STARTING...\e[39m"
					sudo docker container start "${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
				else
					if [ "${STATUS}" == "up" ]; then
						LOG "\e[32m [RESULT] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS RUNNING. RESTARTING...\e[39m"
						sudo docker container restart "${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
					else
						LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') UNKNOWN STATUS: '${CONTAINER}'.\e[39m"
					fi
				fi
				unset STATUS
			fi
			unset CONTAINER
			unset NODE_PORT
		done
	else
		LOG "\e[31m [ERROR] DOCKER IMAGE '${DOCKER_IMAGENAME}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
	fi
	unset NODE_PORTS
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_STATISTICS() {
### Get input variables:
	declare DOCKER_IMAGENAME="${1}"
	declare DOCKER_CONTAINERNAME="${2}"
	declare SCRIPT_NODE_PORT="${3}"
	declare SCRIPT_PORTS="${4}"
	if ! [ -z "${SCRIPT_PORTS}" ]; then
		IFS=',' read -r -a NODE_PORTS <<< "${SCRIPT_PORTS}"
	else
		declare -a NODE_PORTS=("${SCRIPT_NODE_PORT}")
	fi
	unset SCRIPT_PORTS
	unset SCRIPT_NODE_PORT
### Check Docker image exists:
	if ! [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
### Check all ports:
		for NODE_PORT in "${NODE_PORTS[@]}"; do
			declare CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
			if [ -z "${CONTAINER}" ]; then
				LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
			else
### Transform status value to lowercase:
				declare STATUS=$(echo "${CONTAINER}" | sed -e 's/\(.*\)/\L\1/')
				if [ "${STATUS}" == "up" ]; then
# !!! UNKNOWN WHAT TO SHOW AS STATISTICS
					LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') STATISTICS IS NOT DEFINED.\e[39m"
				else
					LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS NOT RUNNING, STATUS IS: '${CONTAINER}'.\e[39m"
				fi
				unset STATUS
			fi
			unset CONTAINER
			unset NODE_PORT
		done
	else
		LOG "\e[31m [ERROR] DOCKER IMAGE '${DOCKER_IMAGENAME}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
	fi
	unset NODE_PORTS
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_LOG() {
### Get input variables:
	declare DOCKER_IMAGENAME="${1}"
	declare DOCKER_CONTAINERNAME="${2}"
	declare SCRIPT_NODE_PORT="${3}"
	declare SCRIPT_PORTS="${4}"
	if ! [ -z "${SCRIPT_PORTS}" ]; then
		IFS=',' read -r -a NODE_PORTS <<< "${SCRIPT_PORTS}"
	else
		declare -a NODE_PORTS=("${SCRIPT_NODE_PORT}")
	fi
	unset SCRIPT_PORTS
	unset SCRIPT_NODE_PORT
### Check Docker image exists:
	if ! [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
### Check all ports:
		for NODE_PORT in "${NODE_PORTS[@]}"; do
			declare CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
			if [ -z "${CONTAINER}" ]; then
				LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
			else
### Transform status value to lowercase:
				declare STATUS=$(echo "${CONTAINER}" | sed -e 's/\(.*\)/\L\1/')
				if [ "${STATUS}" == "exited" ]; then
					LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS STOPPED.\e[39m"
				elif [ "${STATUS}" == "up" ]; then
					LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS RUNNING.\e[39m"
				else
					LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') ERROR STATUS: '${CONTAINER}'.\e[39m"
				fi
				unset STATUS
				LOG "\e[34m [INFO] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' LOG (LAST 100 LINES):\e[39m"
				set +m
#				timeout --kill-after 1s 10s sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --follow --tail 100
				sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --tail 100
				set -m
			fi
			unset CONTAINER
			unset NODE_PORT
		done
	else
		LOG "\e[31m [ERROR] DOCKER IMAGE '${DOCKER_IMAGENAME}' NOT FOUND. CAN NOT CONTINUE.\e[39m"
	fi
	unset NODE_PORTS
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_ACTIVATE() {
### Get input variables:
	declare DOCKER_IMAGENAME="${1}"
	declare DOCKER_CONTAINERNAME="${2}"
	declare DOCKER_DATAPATH="${3}"
	declare NODE_PORT="${4}"
	declare NODE_PROMETHEUS="${5}"
### Compile and create "substrate" project, what finally create two files: "./bin/node/cli" and "./bin/utils/subkey" (we need "subkey").
# https://docs.substrate.io/
# https://github.com/paritytech/substrate/releases
# https://docs.substrate.io/reference/command-line-tools/subkey/
# https://github.com/substrate-developer-hub/knowledgebase/blob/master/current/integrate/subkey.md
# https://core.tetcoin.org/docs/en/knowledgebase/integrate/subkey
### This may take some time and disk space:
#		sudo apt --yes --no-install-recommends install screen
#		screen
#		. <(wget -qO- "https://getsubstrate.io") --
#		curl --proto "=https" -sSf "https://getsubstrate.io" | bash -s --
### Press ^A ^D to detach screen and run screen -r to resume to installation.
### Or simply get compiled "subkey" from GitHub: "https://github.com/equuleus/CRYPTUS/raw/main/NODES/CESS/subkey.tar.gz"
### Check Docker image exists:
	if ! [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
		declare CONTAINER=$(DOCKER_CONTAINER "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}_${NODE_PORT}")
		if ! [ -z "${CONTAINER}" ]; then
			declare STATUS=$(echo "${CONTAINER}" | sed -e 's/\(.*\)/\L\1/')
			if [ "${STATUS}" == "up" ]; then
#				declare FILE_GIT_URL="https://github.com/equuleus/CRYPTUS/raw/main/NODES/CESS/subkey.tar.gz"
				declare FILE_GIT_URL="https://raw.githubusercontent.com/equuleus/CRYPTUS/main/NODES/CESS/subkey.tar.gz"
### Trying to download:
				declare FILE_GIT_INFO=$(wget --spider "${FILE_GIT_URL}" 2>&1)
				if ! [ -z "${FILE_GIT_INFO}" ]; then
### Check content:
					declare FILE_GIT_SIZE=$(echo "${FILE_GIT_INFO}" | grep -oPm1 "(?<=Length\: )([0-9]+)(?= \()")
### If file size detected, we can continue:
					if ! [ -z "${FILE_GIT_SIZE}" ]; then
						LOG "\e[32m [RESULT] FILE SIZE '${FILE_GIT_URL}' FOUND ('${FILE_GIT_SIZE}' bytes).\e[39m"

						declare FILE_PATH_NODE="/root"
						declare FILE_NAME_NODE="cess-node"
						declare FILE_PATH_BASE="${FILE_PATH_NODE}/.cess/base"
						declare FILE_PATH_ARCHIVE="${FILE_PATH_NODE}"
						declare FILE_NAME_ARCHIVE="subkey.tar.gz"
						declare FILE_PATH_PROGRAM="${FILE_PATH_NODE}"
						declare FILE_NAME_PROGRAM="subkey"
						declare FILE_PATH_KEY="/root/.cess"
						declare FILE_NAME_KEY="secretKey.txt"
						if [ -f "${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}" ]; then
							rm -f "${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}"
						fi
						LOG "\e[34m [INFO] TRYING TO DOWNLOAD FILE FROM '${FILE_GIT_URL}' TO '${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}'.\e[39m"
						declare FILE_GIT_DOWNLOAD=$(sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "wget --no-check-certificate --output-document=\"${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}\" \"${FILE_GIT_URL}\"" 2>&1)
						if [ -z '$(echo "${FILE_GIT_DOWNLOAD}" | grep -w "saved \[${FILE_GIT_SIZE}/${FILE_GIT_SIZE}\]")' ]; then
							LOG "\e[31m [ERROR] CAN NOT ACTIVATE NODE IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}', DOWNLOAD FAILED - FILE '${FILE_NAME_ARCHIVE}' DOWNLOAD SIZE NOT MATCH ('"$(wc -c < "${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}")"' of '${FILE_GIT_SIZE}' bytes).\e[39m"
							if [ -f "${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}" ]; then
								sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "rm -f \"${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}\""
							fi
						else
							LOG "\e[32m [RESULT] FILE '${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}' SUCCESSFULLY DOWNLOADED ('${FILE_GIT_SIZE}' bytes).\e[39m"
							sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "tar -xvf \"${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}\" >/dev/null 2>&1"
							sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "rm -f \"${FILE_PATH_ARCHIVE}/${FILE_NAME_ARCHIVE}\""
							sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "chmod +x \"${FILE_PATH_PROGRAM}/${FILE_NAME_PROGRAM}\""
							declare NODE_KEYS=$(sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "\"${FILE_PATH_PROGRAM}/${FILE_NAME_PROGRAM}\" generate --scheme \"sr25519\"")
							if ! [ -z "${NODE_KEYS}" ]; then
								sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "echo \"${NODE_KEYS}\" > \"${FILE_PATH_KEY}/${FILE_NAME_KEY}\""
								LOG "\e[32m [RESULT] KEYS SUCCESSFULLY CREATED:\e[39m"
								IFS=$'\n' read -rd "" -a KEYS_ARRAY <<< ${NODE_KEYS}
								for KEY_STRING in "${KEYS_ARRAY[@]}"; do
									LOG "\e[34m [INFO] ${KEY_STRING}\e[39m"
									unset KEY_STRING
								done
								unset KEYS_ARRAY
								declare SEED=$(echo "${NODE_KEYS}" | grep -w "Secret phrase:" | sed "s/Secret phrase://g" | sed "s/^ *//g")
								if ! [ -z "${SEED}" ]; then
									declare ID=$(echo "${NODE_KEYS}" | grep -w "Account ID:" | sed "s/Account ID://g" | sed "s/^ *//g")
									declare NODE_TEST=$(sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "\"${FILE_PATH_PROGRAM}/${FILE_NAME_PROGRAM}\" inspect --scheme \"sr25519\" \"${SEED}\"")
									if ! [ -z "${NODE_TEST}" ]; then
										declare ID_TEST=$(echo "${NODE_TEST}" | grep -w "Account ID:" | sed "s/Account ID://g" | sed "s/^ *//g")
										if [ "${ID_TEST}" == "${ID}" ]; then
											LOG "\e[32m [RESULT] KEYS SUCCESSFULLY SAVED TO MAPPED DIRECTORY '${DOCKER_DATAPATH}/${NODE_PORT}/${FILE_NAME_KEY}' (IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}': '${FILE_PATH_NODE}/${FILE_NAME_KEY}')\e[39m"
											sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "echo \"${SEED}\" > \"${FILE_PATH_NODE}/${FILE_NAME_KEY}\""
											LOG "\e[32m [INFO] ADD KEYS TO DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}'...\e[39m"
											sleep 1
											LOG "\e[32m [RESULT] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' (IMAGE: '${DOCKER_IMAGENAME}') IS RESTARTING TO APPLY NEW KEYS...\e[39m"
#											sudo docker container restart "${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
											NODE_AUTOSTART_ADD "${DOCKER_DATAPATH}" "${DOCKER_CONTAINERNAME}" "${NODE_PORT}"
										else
											LOG "\e[31m [ERROR] CAN NOT ACTIVATE NODE IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}', GENERATED ACCOUNT ID TEST FAILED.\e[39m"
										fi
										unset ID_TEST
									else
										LOG "\e[31m [ERROR] CAN NOT ACTIVATE NODE IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}', GENERATED SECRET PHRASE TEST FAILED.\e[39m"
									fi
									unset NODE_TEST
									unset ID
								else
									LOG "\e[31m [ERROR] CAN NOT ACTIVATE NODE IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}', GENERATED SECRET PHRASE NOT FOUND.\e[39m"
								fi
								unset SEED
							else
								LOG "\e[31m [ERROR] CAN NOT ACTIVATE NODE IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}', GENERATION OF KEYS RESULT IS EMPTY.\e[39m"
							fi
#							sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" bash -c "rm -f \"${FILE_PATH_PROGRAM}/${FILE_NAME_PROGRAM}\""
						fi
						unset FILE_GIT_DOWNLOAD
						unset FILE_NAME_KEY
						unset FILE_PATH_KEY
						unset FILE_NAME_PROGRAM
						unset FILE_PATH_PROGRAM
						unset FILE_NAME_ARCHIVE
						unset FILE_PATH_ARCHIVE
						unset FILE_PATH_BASE
						unset FILE_NAME_NODE
						unset FILE_PATH_NODE
					else
						LOG "\e[31m [ERROR] CAN NOT ACTIVATE NODE IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}', CAN NOT GET FILE SIZE OF '${FILE_GIT_URL}'.\e[39m"
					fi
					unset FILE_GIT_SIZE
				else
					LOG "\e[31m [ERROR] CAN NOT ACTIVATE NODE IN DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}', CAN NOT GET FILE CONTENT FROM '${FILE_GIT_URL}'.\e[39m"
				fi
				unset FILE_GIT_INFO
				unset FILE_GIT_URL
			else
				LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' IS NOT RUNNING. CAN NOT ACTIVATE NODE.\e[39m"
			fi
			unset STATUS
		else
			LOG "\e[31m [ERROR] DOCKER CONTAINER '${DOCKER_CONTAINERNAME}_${NODE_PORT}' NOT FOUND. CAN NOT ACTIVATE NODE.\e[39m"
		fi
	else
		LOG "\e[31m [ERROR] DOCKER IMAGE '${DOCKER_IMAGENAME}' NOT FOUND. CAN NOT ACTIVATE NODE.\e[39m"
	fi
	unset NODE_PROMETHEUS
	unset NODE_PORT
	unset DOCKER_DATAPATH
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_AUTOSTART_ADD() {
### Get input variables:
	declare DOCKER_DATAPATH="${1}"
	declare DOCKER_CONTAINERNAME="${2}"
	declare NODE_PORT="${3}"
### Create auto-start (save parameters to file):
	echo "[Unit]
Description=Docker Container Autostart Service for \"${DOCKER_CONTAINERNAME}\" on port \"${NODE_PORT}\"
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${DOCKER_DATAPATH}/
ExecStart=/usr/bin/docker container start \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\"
ExecStop=/usr/bin/docker container stop \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\"
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
" > "${DOCKER_DATAPATH}/docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}.service"
### Move APTOS Docker Compose Service to system dicrectory:
	sudo mv "${DOCKER_DATAPATH}/docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}.service" "/etc/systemd/system/"
### Restart and reload system service:
	sudo systemctl restart systemd-journald >/dev/null 2>&1
	sudo systemctl daemon-reload >/dev/null 2>&1
	LOG "\e[32m [RESULT] SYSTEM SERVICE 'docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}' SUCCESSFULLY CREATED.\e[39m"
### Enable and start Docker Container Autostart Service:
	sudo systemctl enable "docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
	sudo systemctl restart "docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
	declare STATUS=$(sudo systemctl is-active "docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}")
	if [ "${STATUS}" == "active" ]; then
		LOG "\e[32m [RESULT] SYSTEM SERVICE 'docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}' START SUCCESSFULL.\e[39m"
	else
		LOG "\e[31m [ERROR] SYSTEM SERVICE 'docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}' START FAILED.\e[39m"
	fi
	unset STATUS
	unset NODE_PORT
	unset DOCKER_CONTAINERNAME
	unset DOCKER_DATAPATH
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_AUTOSTART_REMOVE() {
### Get input variables:
	declare DOCKER_CONTAINERNAME="${1}"
	declare NODE_PORT="${2}"
	if [ -f "/etc/systemd/system/docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}.service" ]; then
### Stop and disable Docker Container Autostart Service:
		sudo systemctl stop "docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
		sudo systemctl disable "docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
### Remove service file:
		sudo rm -f "/etc/systemd/system/docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}.service" >/dev/null 2>&1
### Restart and reload system service:
		sudo systemctl restart systemd-journald
		sudo systemctl daemon-reload
		LOG "\e[32m [RESULT] SYSTEM SERVICE 'docker-${DOCKER_CONTAINERNAME}_${NODE_PORT}' REMOVE SUCCESSFULL.\e[39m"
	fi
	unset NODE_PORT
	unset DOCKER_CONTAINERNAME
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function DOCKER_CONTAINER() {
### Get input variables:
	declare DOCKER_IMAGENAME="${1}"
	declare DOCKER_CONTAINERNAME="${2}"
	declare CONTAINER=""
### Check Docker image exists:
	if ! [ -z "$(sudo docker images --format \"{{.Repository}}\" 2>/dev/null | sed '/^$/d' | grep -w \"${DOCKER_IMAGENAME}\")" ]; then
### If Docker image exists, check Docker container:
		IFS=$'\n' read -rd "" -a DOCKER_ARRAY <<< $(sudo docker ps -a --format "{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null)
		for DOCKER_STRING in "${DOCKER_ARRAY[@]}"; do
			declare -a DOCKER_VALUES=(${DOCKER_STRING//"|"/ })
			declare DOCKER_NAME="${DOCKER_VALUES[0]}"
			declare DOCKER_IMAGE="${DOCKER_VALUES[1]}"
### Transform status value to lowercase:
			declare DOCKER_STATUS=$(echo "${DOCKER_VALUES[2]}" | sed -e 's/\(.*\)/\L\1/')
			if [ "${DOCKER_IMAGE}" == "${DOCKER_IMAGENAME}:latest" ] && [ "${DOCKER_NAME}" == "${DOCKER_CONTAINERNAME}" ]; then
				CONTAINER="${DOCKER_STATUS}"
			fi
			unset DOCKER_STATUS
			unset DOCKER_NAME
			unset DOCKER_IMAGE
			unset DOCKER_VALUES
			unset DOCKER_STRING
		done
		unset DOCKER_ARRAY
	fi
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
	echo "${CONTAINER}"
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
clear
### Get arguments of command line:
for i in "$@"; do
	case $i in
		-i|--install)
			SCRIPT_ACTION="INSTALL"
			shift # past argument with no value
		;;
		-u|--uninstall)
			SCRIPT_ACTION="UNINSTALL"
			shift
		;;
		-r|--restart)
			SCRIPT_ACTION="RESTART"
			shift
		;;
		-s|--statistics)
			SCRIPT_ACTION="STATISTICS"
			shift
		;;
		-l|--log)
			SCRIPT_ACTION="LOG"
			shift
		;;
		-p=*|--ports=*)
			SCRIPT_PORTS="${i#*=}"
			shift # past argument=value
		;;
		-nc|--nocolor)
			SCRIPT_LOG_COLOR=false
			shift
		;;
		-*|--*)
			echo "ERROR: UNKNOWN OPTION '${i}'."
			echo "USAGE: "
			echo "		-i, --install"
			echo "			INSTALL 'CESS' NODE"
			echo "		-u, --uninstall"
			echo "			UNINSTALL 'CESS' NODE"
			echo "		-r, --restart"
			echo "			RESTART 'CESS' NODE"
			echo "		-s, --statistics"
			echo "			SHOW STATISTICS OF 'CESS' NODE"
			echo "		-l, --log"
			echo "			SHOW LOG OF 'CESS' NODE"
			echo "		-p={port(s)_number}, --ports={port(s)_number}"
			echo "			SET 'CESS' NODE PORT(S) NUMBER, EXAMPLE: --ports=9944,9945,9946"
			echo "			IF PORT(S) NOT SET, WILL USE DEFAULT '9944' AND DISPLAY ALL AVAILABLE INFORMATION"
			echo "		-nc, --nocolor"
			echo "			DO NOT USE COLORING IN OUTPUT"
			exit 1
		;;
		*)
		;;
	esac
done
unset i
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
if [ "${SCRIPT_ACTION}" == "INSTALL" ] || [ "${SCRIPT_ACTION}" == "UNINSTALL" ] || [ "${SCRIPT_ACTION}" == "RESTART" ] || [ "${SCRIPT_ACTION}" == "STATISTICS" ] || [ "${SCRIPT_ACTION}" == "LOG" ]; then
	LOG "\e[34m [INFO] STARTING...\e[39m"
	if [ "$(whoami)" != "root" ]; then
		LOG "\e[33m [WARNING] RUNNING AS '$(id -un)'...\e[39m"
#       	 LOG "\e[34m [INFO] AUTHORIZING AS ROOT USER...\e[39m"
#		sudo su -
	fi
	LOG "\e[34m [INFO] SERVER IP: '${IP}'.\e[39m"
### Check input port(s) numbers:
	if ! [ -z "${SCRIPT_PORTS}" ]; then
		declare -a PORTS_LIST
		IFS=', ' read -r -a NODE_PORTS <<< "${SCRIPT_PORTS}"
		for NODE_PORT in "${NODE_PORTS[@]}"; do
			if [ "${NODE_PORT}" -lt "${SCRIPT_NODE_PORT}" ]; then
				LOG "\e[31m [ERROR] INPUT PORT NUMBER '${NODE_PORT}' SHOULD BE GREATER THEN '${SCRIPT_NODE_PORT}'.\e[39m"
			else
				PORT_LIST+=("${NODE_PORT}")
			fi
			unset NODE_PORT
		done
		unset NODE_PORTS
		SCRIPT_PORTS=$(echo "${PORT_LIST[@]}" | sed "s/ /,/g")
		unset PORT_LIST
		LOG "\e[34m [INFO] USING INPUT PORT NUMBER(S): '${SCRIPT_PORTS}'.\e[39m"
	else
### Check database file:
		if [ -f "${DATABASE_FILEPATH}/${DATABASE_FILENAME}" ]; then
			LOG "\e[34m [INFO] FOUND DATABASE FILE '${DATABASE_FILEPATH}/${DATABASE_FILENAME}'.\e[39m"
			declare DATABASE_IP=""
			IFS=$'\n' read -rd "" -a DATABASE_FILE <<< $(cat "${DATABASE_FILEPATH}/${DATABASE_FILENAME}")
			for DATABASE_STRING in "${DATABASE_FILE[@]}"; do
### Removing all spaces (" "), then replacing all "||" to "|#|", then removing "|" from the end of the line, and then removing CR ("\r") from the line:
				DATABASE_STRING=$(echo "${DATABASE_STRING}" | sed "s/ //g" | sed "s/${DATABASE_DELIMITER}${DATABASE_DELIMITER}/${DATABASE_DELIMITER}\#${DATABASE_DELIMITER}/g" | sed "s/${DATABASE_DELIMITER}$//" | sed "s/\r$//")
				declare -a DATABASE_VALUES=(${DATABASE_STRING//"${DATABASE_DELIMITER}"/ })
				if [ "${DATABASE_VALUES[0]:0:1}" != "#" ]; then
					if [ "$IP" == "${DATABASE_VALUES[0]}" ]; then
						DATABASE_IP="${DATABASE_VALUES[0]}"
						for (( i=1; i<"${#DATABASE_VALUES[@]}"; i++ )); do
							if ! [ -z "${DATABASE_VALUES[${i}]}" ] && [ "${DATABASE_VALUES[${i}]}" != "#" ]; then
								if [ -z "${SCRIPT_PORTS}" ]; then
									SCRIPT_PORTS="${DATABASE_VALUES[${i}]}"
								else
									SCRIPT_PORTS="${SCRIPT_PORTS},${DATABASE_VALUES[${i}]}"
								fi
							fi
						done
						unset i
					fi
				fi
				unset DATABASE_VALUES
				unset DATABASE_STRING
			done
			if [ -z "${DATABASE_IP}" ]; then
				LOG "\e[33m [WARNING] SERVER IP '${IP}' NOT FOUND IN DATABASE FILE. USING DEFAULT PORT NUMBER: '${SCRIPT_NODE_PORT}'.\e[39m"
				SCRIPT_PORTS="${SCRIPT_NODE_PORT}"
			else
				if [ -z "${SCRIPT_PORTS}" ]; then
					LOG "\e[33m [WARNING] SERVER IP '${IP}' WAS FOUND IN DATABASE FILE, BUT NO ONE PORTS DEFINED. USING DEFAULT PORT NUMBER: '${SCRIPT_NODE_PORT}'.\e[39m"
					SCRIPT_PORTS="${SCRIPT_NODE_PORT}"
				else
					LOG "\e[32m [RESULT] SERVER IP '${IP}' WAS FOUND IN DATABASE FILE, USING DEFINED PORT NUMBER(S): '${SCRIPT_PORTS}'.\e[39m"
				fi
			fi
			unset DATABASE_FILE
			unset DATABASE_IP
		else
			LOG "\e[34m [INFO] USING DEFAULT PORT NUMBER: '${SCRIPT_NODE_PORT}'.\e[39m"
			SCRIPT_PORTS="${SCRIPT_NODE_PORT}"
		fi
	fi
### Install "Cess" node:
	if [ "${SCRIPT_ACTION}" == "INSTALL" ]; then
		LOG "\e[34m [INFO] INSTALLING 'CESS'...\e[39m"
		SYSTEM
		NODE_INSTALL "${DOCKER_FILEPATH}" "${DOCKER_FILENAME}" "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}" "${DOCKER_DATAPATH}" "${SCRIPT_NODE_PORT}" "${SCRIPT_NODE_PROMETHEUS}" "${SCRIPT_PORTS}"
### Unistall "Cess" node:
	elif [ "${SCRIPT_ACTION}" == "UNINSTALL" ]; then
		LOG "\e[34m [INFO] UNINSTALLING 'CESS'...\e[39m"
		NODE_UNINSTALL "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}" "${SCRIPT_NODE_PORT}" "${SCRIPT_PORTS}"
### Restart "Cess" node:
	elif [ "${SCRIPT_ACTION}" == "RESTART" ]; then
		LOG "\e[34m [INFO] RESTARTING 'CESS'...\e[39m"
		NODE_RESTART "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}" "${SCRIPT_NODE_PORT}" "${SCRIPT_PORTS}"
### Show statistics of "Cess" node:
	elif [ "${SCRIPT_ACTION}" == "STATISTICS" ]; then
		LOG "\e[34m [INFO] 'CESS' STATISTICS...\e[39m"
		NODE_STATISTICS "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}" "${SCRIPT_NODE_PORT}" "${SCRIPT_PORTS}"
### Show log of "Cess" node:
	elif [ "${SCRIPT_ACTION}" == "LOG" ]; then
		LOG "\e[34m [INFO] 'CESS' LOG...\e[39m"
		NODE_LOG "${DOCKER_IMAGENAME}" "${DOCKER_CONTAINERNAME}" "${SCRIPT_NODE_PORT}" "${SCRIPT_PORTS}"
	fi
	LOG "\e[34m [INFO] DONE.\e[39m"
else
	LOG "\e[31m [ERROR] UNKNOWN SCRIPT ACTION '${SCRIPT_ACTION}'. CAN NOT CONTINUE.\e[39m"
fi
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
unset SCRIPT_LOG_COLOR
unset SCRIPT_PORTS
unset SCRIPT_NODE_PROMETHEUS
unset SCRIPT_NODE_PORT
unset SCRIPT_ACTION
unset DATABASE_DELIMITER
unset DATABASE_FILENAME
unset DATABASE_FILEPATH
unset DOCKER_DATAPATH
unset DOCKER_CONTAINERNAME
unset DOCKER_IMAGENAME
unset DOCKER_FILENAME
unset DOCKER_FILEPATH
unset HOME_PATH
unset IP
### -------------------------------------------------------------------------------------------------
