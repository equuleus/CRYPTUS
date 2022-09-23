#!/bin/bash
### -------------------------------------------------------------------------------------------------
# COPYRIGHT: EQUULEUS [https://github.com/equuleus]
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set external IP address:
declare IP=$(wget -qO- eth0.me)
# declare IP=$(curl ifconfig.me) >/dev/null 2>&1
### Set home directory:
if [ "$(whoami)" == "root" ]; then
	declare HOME_PATH="/root"
else
	declare HOME_PATH="/home/$(id -un)"
fi
### Set Docker path and filename:
declare DOCKER_FILEPATH="$HOME_PATH"
declare DOCKER_FILENAME="dockerfile.minima"
declare DOCKER_IMAGENAME="cryptus/minima"
declare DOCKER_CONTAINERNAME="minima"
if [ "$(whoami)" == "root" ]; then
	declare DOCKER_DATAPATH="/root/.minima"
else
	declare DOCKER_DATAPATH="/home/$(id -un)/.minima"
fi
### Set database path, filename and base delimiter:
declare DATABASE_FILEPATH="$HOME_PATH"
declare DATABASE_FILENAME="minima.txt"
declare DATABASE_DELIMITER="|"
### Default script action:
declare SCRIPT_ACTION="STATISTICS"
### Default log style (colored or not):
declare SCRIPT_LOG_COLOR=true
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function LOG() {
	declare TEXT="${1}"
	declare DATE=$(date +"[%Y-%m-%d] [%H:%M:%S]")
	if [ $SCRIPT_LOG_COLOR == true ]; then
		echo -e "$DATE $TEXT"
	else
		echo -e "$DATE $TEXT" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"
	fi
	unset DATE
	unset TEXT
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function SYSTEM() {
### -------------------------------------------------------------------------------------------------
### Set DNS fail-safe server:
	echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
#	echo "nameserver 8.8.8.8" | sudo tee /etc/resolvconf/resolv.conf.d/base > /dev/null
### -------------------------------------------------------------------------------------------------
### Install and update system packages:
	LOG "\e[34m [INFO] INSTALLING AND UPDATING SYSTEM PACKAGES...\e[39m"
	sudo apt update
	sudo apt --yes upgrade
	sudo apt --yes --no-install-recommends install curl wget git sudo unzip
	LOG "\e[32m [RESULT] SYSTEM PACKAGES INSTALLED AND UPDATED SUCCESSFULLY.\e[39m"
### -------------------------------------------------------------------------------------------------
### Install "Docker":
	if ! [ -x "$(command -v docker)" ]; then
		LOG "\e[34m [INFO] INSTALLING \"DOCKER\"...\e[39m"
### Install dependencies needed by the installation process:
		sudo apt --yes --no-install-recommends install apt-transport-https ca-certificates curl gnupg lsb-release
### Add Docker's repository GPG key:
		curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | sudo gpg --dearmor --yes -o "/usr/share/keyrings/docker-archive-keyring.gpg"
#		wget -qO- "https://download.docker.com/linux/ubuntu/gpg" | sudo gpg --dearmor --yes -o "/usr/share/keyrings/docker-archive-keyring.gpg"
### Add the repository to sources:
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
### Or other way to download GPG key and add repository:
#		wget --quiet --output-document=- https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#		sudo add-apt-repository --yes "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release --codename --short) stable"
### Update package lists:
		sudo apt update
### Get "Docker" version (regexp - anything except "_" after "docker-ce | " and before " | https"):
		declare VERSION=$(apt-cache madison docker-ce | grep -oPm1 "(?<=docker-ce \| )([^_]+)(?= \| https)")
### Install "Docker":
		sudo apt --yes --no-install-recommends install docker-ce="$VERSION" docker-ce-cli="$VERSION" containerd.io
#		sudo apt --yes --no-install-recommends install docker-ce docker-ce-cli containerd.io
		unset VERSION
### The Docker daemon runs as root. You must usually prefix Docker commands with sudo. This can get tedious if you're using Docker often. Adding yourself to the docker group will let you use Docker without sudo.
		sudo usermod --append --groups docker "$USER"
#		sudo usermod -aG docker $USER
### Enable service start at boot:
		sudo systemctl enable docker.service
		sudo systemctl enable containerd.service
		if [ "$(sudo systemctl is-active docker)" == "active" ]; then
			LOG "\e[32m [RESULT] \"DOCKER\" INSTALLED SUCCESSFULLY.\e[39m"
		else
### Or other official way to install latest "Docker" from official script:
			LOG "\e[33m [WARNING] \"DOCKER\" WAS NOT INSTALLED, TRYING OTHER WAY TO INSTALL...\e[39m"
			curl -fsSL "https://get.docker.com" -o "./get-docker.sh"
			if [ -f "./get-docker.sh" ]; then
				sudo sh "./get-docker.sh"
				rm -f "./get-docker.sh"
				if [ "$(sudo systemctl is-active docker)" == "active" ]; then
					LOG "\e[32m [RESULT] \"DOCKER\" INSTALLED SUCCESSFULLY.\e[39m"
				else
					LOG "\e[31m [ERROR] \"DOCKER\" WAS NOT INSTALLED. CAN NOT CONTINUE.\e[39m"
					exit
				fi
			else
				LOG "\e[31m [ERROR] \"DOCKER\" NOT DOWNLOADED, PLEASE INSTALL IT MANUALLY. CAN NOT CONTINUE.\e[39m"
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
			LOG "\e[34m [INFO] INSTALLING \"DOCKER COMPOSE\"...\e[39m"
### Get system version and type, then lowercase its values, and finally download actual version for our system to "/usr/local/bin/docker-compose":
			sudo curl -SL "https://github.com/docker/compose/releases/download/${VERSION}/docker-compose-$(uname -s | sed -e 's/\(.*\)/\L\1/')-$(uname -m | sed -e 's/\(.*\)/\L\1/')" -o "/usr/local/bin/docker-compose"
			if [ -f "/usr/local/bin/docker-compose" ]; then
### Set permissions:
				sudo chmod +x "/usr/local/bin/docker-compose"
### Make link:
				sudo ln -s "/usr/local/bin/docker-compose" "/usr/bin/docker-compose"
				. $HOME/.bash_profile
				LOG "\e[32m [RESULT] \"DOCKER COMPOSE\" INSTALLED SUCCESSFULLY.\e[39m"
			else
				LOG "\e[31m [ERROR] \"DOCKER COMPOSE\" NOT DOWNLOADED, PLEASE INSTALL IT MANUALLY. CAN NOT CONTINUE.\e[39m"
				exit
			fi
		else
			LOG "\e[31m [ERROR] \"DOCKER COMPOSE\" ACTUAL VERSION NOT FOUND, PLEASE INSTALL IT MANUALLY. CAN NOT CONTINUE.\e[39m"
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
		IFS=$'\n' read -rd "" -a FIREWALL_RESULT <<< "$FIREWALL_COMMAND"
### Check all our ports:
		for FIREWALL_PORT in "${PORTS[@]}"; do
### Set variable default value:
			declare FIREWALL_RULE_FOUND=false
### Check all lines of firewall configuration:
			for FIREWALL_RULE_LINE in "${FIREWALL_RESULT[@]}"; do
### Check match our port with firewall rule line (if result is not empty):
				if ! [ -z "$(echo \"$FIREWALL_RULE_LINE\" | grep -w \"$FIREWALL_PORT\")" ]; then
					FIREWALL_RULE_FOUND=true
				fi
				unset FIREWALL_RULE_LINE
			done
### If we got a name of a rule, run command to remove it:
			if [ "${FIREWALL_RULE_FOUND}" == false ]; then
				LOG "\e[32m [RESULT] PORT \"$FIREWALL_PORT\" SUCCESSFULLY OPENED IN FIREWALL.\e[39m"
### Add port to firewall:
				sudo ufw allow "$FIREWALL_PORT" >/dev/null 2>&1
			else
				LOG "\e[34m [INFO] PORT \"$FIREWALL_PORT\" ALREADY OPENED IN FIREWALL.\e[39m"
			fi
			unset FIREWALL_RULE_FOUND
			unset FIREWALL_PORT
		done
		unset FIREWALL_RESULT
		unset FIREWALL_COMMAND
	else
		LOG "\e[33m [WARNING] FIREWALL IS NOT IN ACTIVE STATE, CAN NOT ADD PORT(S) \"$PORTS\" TO ALLOW LIST.\e[39m"
	fi
### Check if "IPTables" is installed:
	IPTABLES=$(apt list --installed 2>/dev/null | grep -w "iptables") >/dev/null 2>&1
	if ! [ -z "${IPTABLES}" ]; then
### If it is installed, - run command to add rule with our port:
		for IPTABLES_PORT in "${PORTS[@]}"; do
### Add ports to "IPTables":
# !!! Do the same as firewall...
			sudo iptables -I INPUT -p tcp --dport "$IPTABLES_PORT" -j ACCEPT >/dev/null 2>&1
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
### https://github.com/minima-global/Minima/blob/master/Dockerfile
### https://github.com/minima-global/Minima/blob/master/jar/minima.jar
### https://github.com/minima-global/Minima/blob/master/minima.config
### Get input variables:
	declare NODE_PORT="${1}"
	declare NODE_RPC="${2}"
	declare DOCKER_FILEPATH="${3}"
	declare DOCKER_FILENAME="${4}"
	declare DOCKER_IMAGENAME="${5}"
	declare DOCKER_CONTAINERNAME="${6}"
	declare DOCKER_DATAPATH="${7}"
### Check and create if not exists directory for datapath:
	if ! [ -d "$DOCKER_DATAPATH" ]; then
		mkdir -p "$DOCKER_DATAPATH" >/dev/null 2>&1
	fi
### If Docker image not found, generate it:
	if [ -z "$(sudo docker images 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -w $DOCKER_IMAGENAME)" ]; then
		if [ -f "$DOCKER_FILEPATH/$DOCKER_FILENAME" ]; then
			rm -f "$DOCKER_FILEPATH/$DOCKER_FILENAME"
		fi
		echo "# Base image of system:
FROM alpine
# FROM ubuntu:20.04

# Set metadata, like author info:
LABEL creator=\"EQUULEUS\"
LABEL url=\"https://github.com/equuleus\"

# Set working (current) directory in container:
WORKDIR /root

# Copy file \"entrypoint.sh\" to work directory (set before in \"WORKDIR\" - \"/root\"):
# COPY ./entrypoint.sh .
COPY \"./entrypoint.sh\" \"/root/entrypoint.sh\"
# Grant permissions to execute file \"entrypoint.sh\":
RUN chmod +x \"/root/entrypoint.sh\"

# Install new packages (\"bash\", \"wget\", \"openjdk11\") to Alpine Linux (set before in \"FROM\"):
# \"apk\" - Alpine Linux package manager
RUN apk update && apk upgrade && apk add -U --no-cache bash wget openjdk11
# RUN apt-get update && apt-get --yes upgrade && apt-get --yes --no-install-recommends install \"wget\" \"openjdk-11-jre-headless\" && rm -rf \"/var/lib/apt/lists/*\"

# Open ports \"9001\" and \"9002\":
EXPOSE \"9001\" \"9002\"

# Create volume (to mount it later):
VOLUME \"/root/.minima\"

# Set command (with arguments) wich is executed every time we run container:
ENTRYPOINT [\"/root/entrypoint.sh\"]

# Set command to run when conainer is running (not added to container when it's created):
CMD [\"-Xmx1G\", \"-jar\", \"/root/minima.jar\", \"-data\", \"/root/.minima\", \"-port\", \"9001\", \"-rpcenable\", \"-rpc\", \"9002\", \"-daemon\"]
" > "$DOCKER_FILEPATH/$DOCKER_FILENAME"
		if [ -f "$DOCKER_FILEPATH/$DOCKER_FILENAME" ]; then
			LOG "\e[34m [INFO] DOCKER IMAGE \"$DOCKER_IMAGENAME\" NOT FOUND. TRYING TO CREATE IT...\e[39m"
			if [ -f "$DOCKER_DATAPATH/entrypoint.sh" ]; then
				rm -f "$DOCKER_DATAPATH/entrypoint.sh"
			fi
			echo "#!/bin/bash
wget -qO \"/root/minima.jar\" \"https://github.com/minima-global/Minima/raw/master/jar/minima.jar\"
/usr/bin/java \"\$@\"
" > "$DOCKER_FILEPATH/entrypoint.sh"
			if [ -f "$DOCKER_FILEPATH/entrypoint.sh" ]; then
				sudo docker build -t "$DOCKER_IMAGENAME:latest" -f "$DOCKER_FILENAME" "$DOCKER_FILEPATH"
				rm -f "$DOCKER_FILEPATH/entrypoint.sh"
			else
				LOG "\e[31m [ERROR] FILE \"$DOCKER_FILEPATH/entrypoint.sh\" NOT FOUND. CAN NOT CONTINUE.\e[39m"
			fi
			rm -f "$DOCKER_FILEPATH/$DOCKER_FILENAME"
			if ! [ -z "$(sudo docker images 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -w $DOCKER_IMAGENAME)" ]; then
### Remove Docker container if Docker image was not found and created, but Docker container is already exists:
				if ! [ -z "$(sudo docker ps -a 2>/dev/null | tail -n +2 | awk '{print $2}' | grep -w $DOCKER_IMAGENAME)" ]; then
					LOG "\e[34m [INFO] DOCKER CONTAINER \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\" WAS FOUND. TRYING TO REMOVE IT...\e[39m"
					sudo docker container stop "${DOCKER_CONTAINERNAME}_${NODE_PORT}"
					sudo docker container rm -f -v "${DOCKER_CONTAINERNAME}_${NODE_PORT}"
				fi
### Create and run new Docker container:
				LOG "\e[34m [INFO] TRYING TO CREATE AND START DOCKER CONTAINER \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\"...\e[39m"
				sudo docker run -dit --restart on-failure --name "${DOCKER_CONTAINERNAME}_${NODE_PORT}" -v "$DOCKER_DATAPATH/$NODE_PORT:/root/.minima" -p "$NODE_PORT:9001" -p "$NODE_RPC:9002" "$DOCKER_IMAGENAME:latest"
			else
				LOG "\e[31m [ERROR] DOCKER IMAGE \"$DOCKER_IMAGENAME\" NOT FOUND. CAN NOT CONTINUE.\e[39m"
			fi
		else
			LOG "\e[31m [ERROR] CAN NOT CREATE DOCKER IMAGE \"$DOCKER_IMAGENAME\", FILE "$DOCKER_FILEPATH/$DOCKER_FILENAME" NOT FOUND. CAN NOT CONTINUE.\e[39m"
		fi
	else
		declare CONTAINER=""
### If Docker image exists, check Docker container:
		IFS=$'\n' read -rd "" -a DOCKER_ARRAY <<< $(sudo docker ps -a --format "{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null)
		for DOCKER_STRING in "${DOCKER_ARRAY[@]}"; do
			declare -a DOCKER_VALUES=(${DOCKER_STRING//"|"/ })
			declare DOCKER_NAME="${DOCKER_VALUES[0]}"
			declare DOCKER_IMAGE="${DOCKER_VALUES[1]}"
### Transform status value to lowercase:
			declare DOCKER_STATUS=$(echo "${DOCKER_VALUES[2]}" | sed -e 's/\(.*\)/\L\1/')
			if [ "$DOCKER_IMAGE" == "$DOCKER_IMAGENAME:latest" ] && [ "$DOCKER_NAME" == "${DOCKER_CONTAINERNAME}_${NODE_PORT}" ]; then
				CONTAINER="$DOCKER_NAME"
				if [ "$DOCKER_STATUS" == "exited" ]; then
					sudo docker start "$DOCKER_NAME"
				else
					if [ "$DOCKER_STATUS" == "up" ]; then
						LOG "\e[34m [INFO] DOCKER CONTAINER \"$DOCKER_NAME\" (IMAGE: \"$DOCKER_IMAGE\") ALREADY RUNNING.\e[39m"
					else
						LOG "\e[31m [ERROR] DOCKER CONTAINER \"$DOCKER_NAME\" (IMAGE: \"$DOCKER_IMAGE\") ERROR STATUS: \"${DOCKER_VALUES[2]}\".\e[39m"
					fi
				fi
			fi
			unset DOCKER_STATUS
			unset DOCKER_NAME
			unset DOCKER_IMAGE
			unset DOCKER_VALUES
			unset DOCKER_STRING
		done
		unset DOCKER_ARRAY
### Check if we found our container:
		if [ -z "$CONTAINER" ]; then
			LOG "\e[34m [INFO] DOCKER IMAGE \"$DOCKER_IMAGENAME:latest\" FOUND, BUT CONTAINER NOT FOUND. TRYING TO CREATE AND START IT...\e[39m"
### Create and run new Docker container:
			sudo docker run -dit --restart on-failure --name "${DOCKER_CONTAINERNAME}_${NODE_PORT}" -v "$DOCKER_DATAPATH/$NODE_PORT:/root/.minima" -p "$NODE_PORT:9001" -p "$NODE_RPC:9002" "$DOCKER_IMAGENAME:latest"
		fi
		unset CONTAINER
	fi
### Pause 60 seconds...
#	sleep 60
	set +m
	timeout --kill-after 1s 60s sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --follow --tail 100
	set -m
### Check version:
	declare NODE_VERSION=$(wget -qO- "localhost:${NODE_RPC}/status" | grep -oPm1 "(?<=\"version\":\")(.*?)(?=\")")
#	declare NODE_VERSION=$(curl "127.0.0.1:${NODE_RPC}/status" | jq | grep "version")
	if ! [ -z "$NODE_VERSION" ]; then
		LOG "\e[32m [RESULT] NODE \"Minima\" v.\"$NODE_VERSION\" SUCCESSFULLY STARTED FROM DOCKER CONTAINER \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\".\e[39m"
	else
		LOG "\e[31m [ERROR] NODE \"Minima\" NOT STARTED, PLEASE CHECK LOGS:\e[39m"
### Show Docker container logs (last 100 lines):
		sudo docker container logs "${DOCKER_CONTAINERNAME}_${NODE_PORT}" --tail 100
	fi
	unset NODE_VERSION
	unset DOCKER_DATAPATH
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
	unset DOCKER_FILENAME
	unset DOCKER_FILEPATH
	unset NODE_RPC
	unset NODE_PORT
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_UNINSTALL() {
### Get input variables:
	declare NODE_PORT="${1}"
	declare NODE_RPC="${2}"
	declare DOCKER_IMAGENAME="${3}"
	declare DOCKER_CONTAINERNAME="${4}"
### Check Docker container for removing:
	declare CONTAINER=""
	IFS=$'\n' read -rd "" -a DOCKER_ARRAY <<< $(sudo docker ps -a --format "{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null)
	for DOCKER_STRING in "${DOCKER_ARRAY[@]}"; do
		declare -a DOCKER_VALUES=(${DOCKER_STRING//"|"/ })
		declare DOCKER_NAME="${DOCKER_VALUES[0]}"
		declare DOCKER_IMAGE="${DOCKER_VALUES[1]}"
### Transform status value to lowercase:
		declare DOCKER_STATUS=$(echo "${DOCKER_VALUES[2]}" | sed -e 's/\(.*\)/\L\1/')
		if [ "$DOCKER_IMAGE" == "$DOCKER_IMAGENAME:latest" ] && [ "$DOCKER_NAME" == "${DOCKER_CONTAINERNAME}_${NODE_PORT}" ]; then
			CONTAINER="TRUE"
			LOG "\e[34m [INFO] DOCKER CONTAINER \"$DOCKER_NAME\" (IMAGE: \"$DOCKER_IMAGE\") WAS FOUND. TRYING TO REMOVE IT...\e[39m"
			if [ "$DOCKER_STATUS" != "exited" ]; then
#				LOG "\e[34m [INFO] STOPPING DOCKER CONTAINER \"$DOCKER_NAME\" (IMAGE: \"$DOCKER_IMAGE\")...\e[39m"
				sudo docker stop "$DOCKER_NAME" >/dev/null 2>&1
			fi
#			LOG "\e[34m [INFO] REMOVING DOCKER CONTAINER \"$DOCKER_NAME\" (IMAGE: \"$DOCKER_IMAGE\") AND IT'S VOLUME...\e[39m"
			sudo docker container rm --force --volumes "$DOCKER_NAME" >/dev/null 2>&1
		fi
		unset DOCKER_STATUS
		unset DOCKER_NAME
		unset DOCKER_IMAGE
		unset DOCKER_VALUES
		unset DOCKER_STRING
	done
	unset DOCKER_ARRAY
	declare IMAGE=false
	IFS=$'\n' read -rd "" -a DOCKER_ARRAY <<< $(sudo docker ps -a --format "{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null)
	for DOCKER_STRING in "${DOCKER_ARRAY[@]}"; do
		declare -a DOCKER_VALUES=(${DOCKER_STRING//"|"/ })
		declare DOCKER_NAME="${DOCKER_VALUES[0]}"
		declare DOCKER_IMAGE="${DOCKER_VALUES[1]}"
		if [ "$DOCKER_IMAGE" == "$DOCKER_IMAGENAME:latest" ]; then
			IMAGE=true
			if [ "$CONTAINER" == "TRUE" ]; then
				if [ "$DOCKER_NAME" == "${DOCKER_CONTAINERNAME}_${NODE_PORT}" ]; then
					CONTAINER="FALSE"
				fi
			fi
		fi
		unset DOCKER_NAME
		unset DOCKER_IMAGE
		unset DOCKER_VALUES
		unset DOCKER_STRING
	done
	unset DOCKER_ARRAY
	if [ "$CONTAINER" == "TRUE" ]; then
		LOG "\e[32m [RESULT] DOCKER CONTAINER \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\" REMOVE SUCCESSFULL.\e[39m"
	elif [ "$CONTAINER" == "FALSE" ]; then
		LOG "\e[31m [ERROR] DOCKER CONTAINER \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\" REMOVE FAILED.\e[39m"
	else
		LOG "\e[34m [INFO] DOCKER CONTAINER \"${DOCKER_CONTAINERNAME}_${NODE_PORT}\" NOT FOUND. NOTHING TO DO.\e[39m"
	fi
	unset CONTAINER
### Check Docker image for removing:
	if [ "$IMAGE" == false ]; then
		LOG "\e[34m [INFO] NO DOCKER CONTAINERS. SEARCHING FOR DOCKER IMAGE \"$DOCKER_IMAGENAME\"...\e[39m"
### If Docker image not found, generate it:
		if ! [ -z "$(sudo docker images 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -w $DOCKER_IMAGENAME)" ]; then
			LOG "\e[34m [INFO] DOCKER IMAGE \"$DOCKER_IMAGENAME\" WAS FOUND. TRYING TO REMOVE IT...\e[39m"
			sudo docker image rm --force "$DOCKER_IMAGENAME" >/dev/null 2>&1
			if [ -z "$(sudo docker images 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -w $DOCKER_IMAGENAME)" ]; then
				LOG "\e[32m [RESULT] DOCKER IMAGE \"$DOCKER_IMAGENAME\" REMOVE SUCCESSFULL.\e[39m"
			else
				LOG "\e[31m [ERROR] DOCKER IMAGE \"$DOCKER_IMAGENAME\" REMOVE FAILED.\e[39m"
			fi
		else
			LOG "\e[34m [INFO] DOCKER IMAGE \"$DOCKER_IMAGENAME\" NOT FOUND. NOTHING TO DO.\e[39m"
		fi
	fi
	unset IMAGE
	unset DOCKER_CONTAINERNAME
	unset DOCKER_IMAGENAME
	unset NODE_RPC
	unset NODE_PORT
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_RESTART() {
### Get input variables:
	declare NODE_PORT="${1}"
	declare NODE_RPC="${2}"
	declare DOCKER_CONTAINERNAME="${3}"
### Make a request to Docker container:
#	sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" ls -la "/root/.minima"
#	sudo docker container exec "${DOCKER_CONTAINERNAME}_${NODE_PORT}" shutdown -r
### Restart node:
#	wget -qO- "localhost:${NODE_RPC}/quit" && sleep 10 && sudo docker container start "${DOCKER_CONTAINERNAME}_${NODE_PORT}"
	wget -qO- "localhost:${NODE_RPC}/quit" >/dev/null 2>&1
	sleep 10
	sudo docker container restart --time 10 "${DOCKER_CONTAINERNAME}_${NODE_PORT}" >/dev/null 2>&1
	unset DOCKER_CONTAINERNAME
	unset NODE_RPC
	unset NODE_PORT
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_STATISTICS() {
### Get input variables:
	declare DATABASE_RPC="${1}"
	declare DATABASE_UID="${2}"
	declare NODE_RESPONSE=$(wget -qO- "localhost:$DATABASE_RPC/status")
	if ! [ -z "$NODE_RESPONSE" ]; then
		LOG "\e[32m [RESULT] NODE STATISTICS ON PORT \"$DATABASE_RPC\"...\e[39m"
		declare NODE_VERSION=$(echo "$NODE_RESPONSE" | grep -oPm1 "(?<=\"version\":\")(.*?)(?=\")")
		if ! [ -z "$NODE_VERSION" ]; then
			LOG "\e[32m [RESULT]	\"version\": \"$NODE_VERSION\"\e[39m"
		fi
		unset NODE_VERSION
		NODE_RESPONSE=$(wget -qO- "localhost:$DATABASE_RPC/incentivecash")
		if ! [ -z "$NODE_RESPONSE" ]; then
			declare NODE_STATUS=$(echo "$NODE_RESPONSE" | grep -oPm1 "(?<=\"status\":)(.*?)(?=,)")
			if [ "$NODE_STATUS" == "true" ]; then
				LOG "\e[32m [RESULT]	\"status\": \"$NODE_STATUS\"\e[39m"
				for NODE_NAME in "uid" "lastPing" "inviteCode"; do
					declare NODE_VALUE=$(echo "$NODE_RESPONSE" | grep -oPm1 "(?<=\"$NODE_NAME\":\")(.*?)(?=\")")
					LOG "\e[32m [RESULT]	\"${NODE_NAME}\": \"$NODE_VALUE\"\e[39m"
					unset NODE_VALUE
					unset NODE_NAME
				done
				for NODE_NAME in "dailyRewards" "previousRewards" "communityRewards" "inviterRewards"; do
					declare NODE_VALUE=$(echo "$NODE_RESPONSE" | grep -oPm1 "(?<=\"$NODE_NAME\":)(.*?)(?=[,}])")
					LOG "\e[32m [RESULT]	\"${NODE_NAME}\": \"$NODE_VALUE\"\e[39m"
					unset NODE_VALUE
					unset NODE_NAME
				done
			else
				LOG "\e[31m [ERROR] NODE STATUS UKNOWN RESULT: \"$NODE_STATUS\".\e[39m"
			fi
			unset NODE_STATUS
			declare NODE_UID=$(echo "$NODE_RESPONSE" | grep -oPm1 "(?<=\"uid\":\")(.*?)(?=\")")
			if [ "$DATABASE_UID" == "$NODE_UID" ]; then
				LOG "\e[32m [RESULT] UID IN DATABASE \"$DATABASE_UID\" AND NODE STATUS \"$NODE_UID\" ARE MATCH.\e[39m"
			else
				LOG "\e[31m [ERROR] UID IN DATABASE \"$DATABASE_UID\" AND NODE STATUS \"$NODE_UID\" NOT MATCH.\e[39m"
				NODE_ACTIVATE "$DATABASE_RPC" "$DATABASE_UID"
			fi
			unset NODE_UID
		else
			LOG "\e[31m [ERROR] NODE REQUESTED \"INCENTIVECASH\" RESPONSE IS EMPTY.\e[39m"
		fi
	else
		LOG "\e[31m [ERROR] NODE REQUESTED \"STATUS\" RESPONSE IS EMPTY ON PORT \"$DATABASE_RPC\". CAN NOT GET STATISTICS.\e[39m"
	fi
	unset NODE_RESPONSE
	unset DATABASE_UID
	unset DATABASE_RPC
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_ACTIVATE() {
### Get input variables:
	declare NODE_RPC="${1}"
	declare NODE_UID="${2}"
	declare NODE_VERSION=$(wget -qO- "localhost:$NODE_RPC/status" | grep -oPm1 "(?<=\"version\":\")(.*?)(?=\")")
	if ! [ -z "$NODE_VERSION" ]; then
### Register node ID:
		declare NODE_RESPONSE=$(wget -qO- "localhost:${NODE_RPC}/incentivecash%20uid:${NODE_UID}")
#		declare NODE_RESPONSE=$(curl "127.0.0.1:${NODE_RPC}/incentivecash+uid:${NODE_UID}" | jq)
		if ! [ -z "$(echo \"${NODE_RESPONSE}\" | grep -w \"${NODE_UID}\")" ]; then
			LOG "\e[32m [RESULT] UID \"$NODE_UID\" UPDATED SUCCESSFULLY.\e[39m"
		else
			LOG "\e[31m [ERROR] UID \"$NODE_UID\" UPDATE FAILED.\e[39m"
		fi
	else
		LOG "\e[31m [ERROR] NODE REQUESTED STATUS FAILED. CAN NOT ACTIVATE IT.\e[39m"
	fi
	unset NODE_VERSION
	unset NODE_UID
	unset NODE_RPC
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
clear
### Get arguments of command line:
for i in "$@"; do
	case $i in
#		-i=*|--install=*)
#			EXTENSION="${i#*=}"
#			shift # past argument=value
#		;;
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
		-nc|--nocolor)
			SCRIPT_LOG_COLOR=false
			shift
		;;
		-*|--*)
			echo "ERROR: unknown option \"$i\"."
			echo "Usage: "
			echo "		-i, --install"
			echo "			install \"Minima\" node(s)"
			echo "		-u, --uninstall"
			echo "			uninstall \"Minima\" node(s)"
			echo "		-r, --restart"
			echo "			restart \"Minima\" node(s) [with Docker container]"
			echo "		-s, --statistics"
			echo "			show statistics of \"Minima\" node(s)"
			echo "		-nc, --nocolor"
			echo "			do not use coloring in output"
			exit 1
		;;
		*)
		;;
	esac
done
unset i
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
if [ "$SCRIPT_ACTION" == "INSTALL" ] || [ "$SCRIPT_ACTION" == "UNINSTALL" ] || [ "$SCRIPT_ACTION" == "RESTART" ] || [ "$SCRIPT_ACTION" == "STATISTICS" ]; then
	if [ "$(whoami)" != "root" ]; then
		LOG "\e[33m [WARNING] RUNNING AS \"$(id -un)\"...\e[39m"
#       	 LOG "\e[34m [INFO] AUTHORIZING AS ROOT USER...\e[39m"
#		sudo su -
	fi
### Read content of database file:
	LOG "\e[34m [INFO] STARTING...\e[39m"
	LOG "\e[34m [INFO] SERVER IP: \"$IP\"\e[39m"
	if [ -f "$DATABASE_FILEPATH/$DATABASE_FILENAME" ]; then
		declare DATABASE_IP=""
		IFS=$'\n' read -rd "" -a DATABASE_FILE <<< $(cat "$DATABASE_FILEPATH/$DATABASE_FILENAME")
		for DATABASE_STRING in "${DATABASE_FILE[@]}"; do
### Removing all spaces (" "), then replacing all "||" to "|#|", then removing "|" from the end of the line, and then removing CR ("\r") from the line:
			DATABASE_STRING=$(echo "$DATABASE_STRING" | sed "s/ //g" | sed "s/${DATABASE_DELIMITER}${DATABASE_DELIMITER}/${DATABASE_DELIMITER}\#${DATABASE_DELIMITER}/g" | sed "s/${DATABASE_DELIMITER}$//" | sed "s/\r$//")
			declare -a DATABASE_VALUES=(${DATABASE_STRING//"$DATABASE_DELIMITER"/ })
			if [ "${DATABASE_VALUES[0]:0:1}" != "#" ]; then
				if [ "$IP" == "${DATABASE_VALUES[0]}" ]; then
					DATABASE_IP="${DATABASE_VALUES[0]}"
					for (( i=1; i<"${#DATABASE_VALUES[@]}"; i++ )); do
### Generate ports from ID position:
						declare -i j=($i-1)
						declare DATABASE_PORT="90${j}1"
						declare DATABASE_RPC="90${j}2"
						unset j
						LOG "\e[34m [INFO] WORKING WITH PORT \"$DATABASE_PORT\" AND RPC \"$DATABASE_RPC\"...\e[39m"
						if ! [ -z "${DATABASE_VALUES[$i]}" ] && [ "${DATABASE_VALUES[$i]}" != "#" ]; then
### Install "Minima":
							if [ "$SCRIPT_ACTION" == "INSTALL" ]; then
### Check necessary ports:
								declare TEST=""
								for PORT in "$DATABASE_PORT" "$DATABASE_RPC"; do
									if [ -z "$TEST" ]; then
										TEST=$(ss -tulpen | awk '{print $5}' | grep ":$PORT$")
										if ! [ -z "$TEST" ]; then
											LOG "\e[31m [ERROR] INSTALLATION ON PORT \"$PORT\" IS NOT POSSIBLE, PORT IS ALREADY IN USE.\e[39m"
										fi
									fi
									unset PORT
								done
### Execute all functions:
								if [ -z "$TEST" ]; then
									LOG "\e[34m [INFO] INSTALLING \"MINIMA\"...\e[39m"
									SYSTEM
### Opening only primary port (not RPC):
#									PORTS "($DATABASE_PORT $DATABASE_RPC)"
									PORTS "($DATABASE_PORT)"
									NODE_INSTALL "$DATABASE_PORT" "$DATABASE_RPC" "$DOCKER_FILEPATH" "$DOCKER_FILENAME" "$DOCKER_IMAGENAME" "$DOCKER_CONTAINERNAME" "$DOCKER_DATAPATH"
									NODE_ACTIVATE "$DATABASE_RPC" "${DATABASE_VALUES[$i]}"
								else
									NODE_STATISTICS "$DATABASE_RPC" "${DATABASE_VALUES[$i]}"
								fi
								unset TEST
### Restart / update "Minima" (node stop and Docker container restart):
							elif [ "$SCRIPT_ACTION" == "RESTART" ]; then
								LOG "\e[34m [INFO] RESTARTING \"MINIMA\"...\e[39m"
								NODE_RESTART "$DATABASE_PORT" "$DATABASE_RPC" "$DOCKER_CONTAINERNAME"
### Show statistics of "Minima":
							elif [ "$SCRIPT_ACTION" == "STATISTICS" ]; then
								NODE_STATISTICS "$DATABASE_RPC" "${DATABASE_VALUES[$i]}"
							fi
							unset DATABASE_RPC
							unset DATABASE_PORT
						else
### Uninstall "Minima":
							if [ "$SCRIPT_ACTION" == "UNINSTALL" ]; then
								LOG "\e[34m [INFO] UNINSTALLING \"MINIMA\"...\e[39m"
								NODE_UNINSTALL "$DATABASE_PORT" "$DATABASE_RPC" "$DOCKER_IMAGENAME" "$DOCKER_CONTAINERNAME"
							else
								if ! [ -z "$(sudo docker ps -a --format \"{{.Names}}\" | grep \"${DOCKER_CONTAINERNAME}_${DATABASE_PORT}\")" ]; then
									LOG "\e[33m [WARNING] FOUND INSTALLATION ON PORT \"$DATABASE_PORT\" WITHOUT \"ID\", RUN SCRIPT WITH ARGUMENT \"--uninstall\".\e[39m"
								fi
							fi
						fi
					done
					unset i
				fi
			fi
			unset DATABASE_VALUES
			unset DATABASE_STRING
		done
		if [ -z "$DATABASE_IP" ]; then
			LOG "\e[31m [ERROR] SERVER IP "$IP" NOT FOUND IN DATABASE FILE. CAN NOT CONTINUE.\e[39m"
		fi
		unset DATABASE_FILE
		unset DATABASE_IP
	else
		LOG "\e[31m [ERROR] DATABASE FILE "$DATABASE_FILEPATH/$DATABASE_FILENAME" NOT FOUND. CAN NOT CONTINUE.\e[39m"
	fi
	LOG "\e[34m [INFO] DONE.\e[39m"
else
	LOG "\e[31m [ERROR] UNKNOWN SCRIPT ACTION \"$SCRIPT_ACTION\". CAN NOT CONTINUE.\e[39m"
fi
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
unset SCRIPT_LOG_COLOR
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
