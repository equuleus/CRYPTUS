#!/bin/bash
### -------------------------------------------------------------------------------------------------
# COPYRIGHT: EQUULEUS [https://github.com/equuleus]
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
# https://docs.massa.net/en/latest/testnet/install.html
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set node password:
declare PASSWORD="CRYPTUS"
### Set external IP address:
declare IP=$(wget -qO- eth0.me) >/dev/null 2>&1
# declare IP=$(curl ifconfig.me) >/dev/null 2>&1
### Default working ports:
declare -a PORTS=("31244" "31245")
### Set home directory:
if [ "$(whoami)" == "root" ]; then
	declare HOME_PATH="/root"
else
	declare HOME_PATH="/home/$(id -un)"
fi
### Set node working path:
declare NODE_PATH="$HOME_PATH/massa"
### Set node backup path:
declare BACKUP_PATH="$HOME_PATH/massa_backup"
### Set database path, filename and base delimiter:
declare DATABASE_FILEPATH="$HOME_PATH"
declare DATABASE_FILENAME="massa.txt"
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
	sudo apt --yes --no-install-recommends install wget sudo
#	sudo apt --yes --no-install-recommends install curl wget sudo
	LOG "\e[32m [RESULT] SYSTEM PACKAGES INSTALLED AND UPDATED SUCCESSFULLY.\e[39m"
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_UPDATE() {
### Get input variables:
	declare HOME_PATH="${1}"
	declare NODE_PATH="${2}"
	declare BACKUP_PATH="${3}"
	declare NODE_IP="${4}"
	declare NODE_PASSWORD="${5}"
	declare NODE_GIT="https://api.github.com/repos/massalabs/massa/releases/latest"
### Get current node version:
	if [ -f "$NODE_PATH/massa-node/massa-node" ]; then
		cd "$NODE_PATH/massa-node"
		set +m
		declare NODE_VERSION_LOCAL=$(timeout --kill-after 1s 1s "$NODE_PATH/massa-node/massa-node" --pwd "$NODE_PASSWORD" 2>/dev/null | grep -oPm1 "(?<=Node version \: )(.*)")
		set -m
		cd "$HOME_PATH"
	else
		declare NODE_VERSION_LOCAL=""
	fi
### Download "https://api.github.com/repos/massalabs/massa/releases/latest" and select "tag_name" value from it, then cut first character "v":
	declare NODE_VERSION_WEB=$(wget --quiet --output-document=- "$NODE_GIT" | grep --perl-regexp --only-matching '"tag_name": "\K.*?(?=")' | sed "s/^v//")
### Or other way to do the same with "jq":
#	sudo apt --yes --no-install-recommends install jq
#	declare NODE_VERSION_WEB=$(wget -qO- "$NODE_GIT" | jq -r ".tag_name" | sed "s/^v//")
	if [ "$NODE_VERSION_LOCAL" != "$NODE_VERSION_WEB" ] && ! [ -z "$NODE_VERSION_WEB" ]; then
		if ! [ -z "$NODE_VERSION_LOCAL" ]; then
			LOG "\e[34m [INFO] 'MASSA' NODE VERSION: '$NODE_VERSION_LOCAL'.\e[39m"
		else
			LOG "\e[34m [INFO] 'MASSA' NODE VERSION UNKNOWN.\e[39m"
		fi
		LOG "\e[34m [INFO] 'MASSA' WEB VERSION: '$NODE_VERSION_WEB'.\e[39m"
		declare NODE_URL="https://github.com/massalabs/massa/releases/download/${NODE_VERSION_WEB}/massa_${NODE_VERSION_WEB}_release_linux.tar.gz"
### Download file from web with actual version:
		wget -qO "$HOME_PATH/massa.tar.gz" "$NODE_URL" >/dev/null 2>&1
		if [ -f "$HOME_PATH/massa.tar.gz" ]; then
			declare FILE_SIZE=$(wc -c < "$HOME_PATH/massa.tar.gz")
### Check file size (more then 1000 bytes):
			if [ $FILE_SIZE -ge 1000 ]; then
#				LOG "\e[32m [RESULT] FILE SUCCESSFULLY DOWNLOADED FROM '$NODE_URL' AND SAVED TO '$HOME_PATH/massa.tar.gz'.\e[39m"
### Stop node service:
				sudo systemctl stop massad >/dev/null 2>&1
### Backup important files:
				if [ -d "$BACKUP_PATH" ] && [ -f "$NODE_PATH/massa-node/config/node_privkey.key" ] && [ -f "$HOME/massa/massa-client/wallet.dat" ]; then
					LOG "\e[32m [RESULT] BACKUP FILES ('$NODE_PATH/massa-node/config/node_privkey.key' and '$NODE_PATH/massa-client/wallet.dat') TO '$BACKUP_PATH'...\e[39m"
					sudo cp -f "$NODE_PATH/massa-node/config/node_privkey.key" "$BACKUP_PATH/node_privkey.key"
					sudo cp -f "$NODE_PATH/massa-client/wallet.dat" "$BACKUP_PATH/wallet.dat"
				else
					if ! [ -d "$BACKUP_PATH" ]; then
						LOG "\e[32m [RESULT] CREATING BACKUP DIRECTORY '$BACKUP_PATH'...\e[39m"
						mkdir -p "$BACKUP_PATH"
					fi
					if [ -d "$BACKUP_PATH" ]; then
						if [ -d "$NODE_PATH/massa-node" ]; then
							LOG "\e[32m [RESULT] BACKUP FILE '$HOME/massa/massa-node/config/node_privkey.key' TO '$BACKUP_PATH'...\e[39m"
							declare -i COUNTER=0
							while true; do
								if [ -f "$HOME/massa/massa-node/config/node_privkey.key" ]; then
									sudo cp -f "$HOME/massa/massa-node/config/node_privkey.key" "$BACKUP_PATH/node_privkey.key"
									break
								fi
								if [ $COUNTER -ge 60 ]; then
									LOG "\e[31m [ERROR] BACKUP FILE "$HOME/massa/massa-node/config/node_privkey.key" FAILED (TIMEOUT 60 SECONDS).\e[39m"
									break
								else
									COUNTER=($COUNTER+5)
									sleep 5
								fi
							done
							unset COUNTER
						else
							LOG "\e[31m [ERROR] DIRECTORY '$NODE_PATH/massa-node' NOT FOUND.\e[39m"
						fi
						if [ -d "$NODE_PATH/massa-client" ]; then
							if [ -f "$NODE_PATH/massa-client/massa-client" ]; then
								if ! [ -f "$HOME/massa/massa-client/wallet.dat" ]; then
									LOG "\e[32m [RESULT] GENERATING SECRET KEY: '$HOME/massa/massa-client/wallet.dat'...\e[39m"
									"$NODE_PATH/massa-client/massa-client" -p "$massa_password" wallet_generate_secret_key 2>/dev/null
								fi
								if [ -f "$HOME/massa/massa-client/wallet.dat" ]; then
									LOG "\e[32m [RESULT] BACKUP FILE '$HOME/massa/massa-client/wallet.dat' TO '$BACKUP_PATH'...\e[39m"
									sudo cp -f "$HOME/massa/massa-client/wallet.dat" "$BACKUP_PATH/wallet.dat"
								else
									LOG "\e[31m [ERROR] GENERATING SECRET KEY FAILED.\e[39m"
								fi
							else
								LOG "\e[31m [ERROR] FILE '$NODE_PATH/massa-client/massa-client' NOT FOUND.\e[39m"
							fi
						else
							LOG "\e[31m [ERROR] DIRECTORY '$NODE_PATH/massa-client' NOT FOUND.\e[39m"
						fi
					else
						LOG "\e[31m [ERROR] CREATING DIRECTORY '$BACKUP_PATH' FAILED.\e[39m"
					fi
				fi
				if [ -d "$BACKUP_PATH" ] && [ -f "$BACKUP_PATH/node_privkey.key" ] && [ -f "$BACKUP_PATH/wallet.dat" ]; then
### Unpack archive file:
					tar -xvf "$HOME_PATH/massa.tar.gz" >/dev/null 2>&1
### Restore important files:
					if [ -d "$BACKUP_PATH" ]; then
						LOG "\e[32m [RESULT] RESTORE FILE FROM '$BACKUP_PATH/node_privkey.key' TO '$NODE_PATH/massa-node/config/node_privkey.key'...\e[39m"
						sudo cp -f "$BACKUP_PATH/node_privkey.key" "$NODE_PATH/massa-node/config/node_privkey.key"
						LOG "\e[32m [RESULT] RESTORE FILE FROM '$BACKUP_PATH/wallet.dat' TO '$NODE_PATH/massa-client/wallet.dat'...\e[39m"
						sudo cp -f "$BACKUP_PATH/wallet.dat" "$NODE_PATH/massa-client/wallet.dat"
					fi
### Change IP address in configuration:
					sudo tee <<EOF >/dev/null $NODE_PATH/massa-node/config/config.toml
[network]
routable_ip = "$NODE_IP"
EOF
					if [ -f "$NODE_PATH/massa-node/massa-node" ]; then
### Set permissions to unpacked file:
						chmod +x "$NODE_PATH/massa-node/massa-node"
### Re-check node version:
						cd "$NODE_PATH/massa-node"
						set +m
						NODE_VERSION_LOCAL=$(timeout --kill-after 1s 1s "$NODE_PATH/massa-node/massa-node" --pwd "$NODE_PASSWORD" 2>/dev/null | grep -oPm1 "(?<=Node version \: )(.*)")
						set -m
						cd "$HOME_PATH"
### Start node service:
						sudo systemctl restart massad >/dev/null 2>&1
						if [ "$NODE_VERSION_LOCAL" == "$NODE_VERSION_WEB" ]; then
							LOG "\e[32m [RESULT] 'MASSA' UPDATED SUCCESSFULLY.\e[39m"
						else
							LOG "\e[31m [ERROR] 'MASSA' UPDATE FAILED.\e[39m"
						fi
						if ! [ -z "$NODE_VERSION_LOCAL" ]; then
							LOG "\e[34m [INFO] 'MASSA' NODE VERSION: '$NODE_VERSION_LOCAL'.\e[39m"
						else
							LOG "\e[34m [INFO] 'MASSA' NODE VERSION UNKNOWN.\e[39m"
						fi
					else
						LOG "\e[31m [ERROR] FILE '$NODE_PATH/massa-node/massa-node' NOT FOUND.\e[39m"
					fi
					if [ -f "$NODE_PATH/massa-client/massa-client" ]; then
### Set permissions to unpacked file:
						chmod +x "$NODE_PATH/massa-client/massa-client"
					else
						LOG "\e[31m [ERROR] FILE '$NODE_PATH/massa-client/massa-client' NOT FOUND.\e[39m"
					fi
				else
					LOG "\e[31m [ERROR] BACKUP FILES FAILED.\e[39m"
				fi
			else
				LOG "\e[31m [ERROR] FILE '$HOME_PATH/massa.tar.gz' SIZE IS TOO SMALL ['$FILE_SIZE' byte(s)].\e[39m"
			fi
			unset FILE_SIZE
### Removing downloaded file:
			rm -f "$HOME_PATH/massa.tar.gz"
		else
			LOG "\e[31m [ERROR] CAN NOT DOWNLOAD FILE FROM '$NODE_URL' TO '$HOME_PATH/massa.tar.gz'.\e[39m"
		fi
		unset NODE_URL
	else
		if ! [ -z "$NODE_VERSION_WEB" ]; then
			LOG "\e[32m [RESULT] 'MASSA' VERSION IS IN ACTUAL STATE ('$NODE_VERSION_WEB').\e[39m"
		else
			LOG "\e[31m [ERROR] CAN NOT DOWNLOAD GET ACTUAL VERSION FROM '$NODE_GIT'.\e[39m"
		fi
	fi
	unset NODE_VERSION_WEB
	unset NODE_VERSION_LOCAL
	unset NODE_GIT
	unset NODE_PASSWORD
	unset NODE_IP
	unset BACKUP_PATH
	unset NODE_PATH
	unset HOME_PATH
}
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
function NODE_STATISTICS() {
### Get input variables:
	declare HOME_PATH="${1}"
	declare NODE_PATH="${2}"
	declare NODE_IP="${3}"
	declare NODE_PASSWORD="${4}"
### Get "wallet_info" command response:
	cd "$NODE_PATH/massa-client"
	declare NODE_RESPONSE=$("$NODE_PATH/massa-client/massa-client" --pwd "$NODE_PASSWORD" wallet_info)
	cd "$HOME_PATH"
	if ! [ -z "$NODE_RESPONSE" ]; then
# !!!
#		NODE_RESPONSE=$(echo "$NODE_RESPONSE" | grep -v '^\s*$' | tail -n +2 | head -n -1)
#		IFS=$'|' read -rd "" -a RESULTS <<< "${NODE_RESPONSE//=====/|}"
		NODE_RESPONSE=$(echo "$NODE_RESPONSE" | grep -v '^\s*$' | tail -n +2)
		declare -i LINE_TOTAL=$(echo "$NODE_RESPONSE" | grep "" -c)
#sed "5!d" "$NODE_RESPONSE"
		declare -a TEXT
		declare -a NODE_WALLETS=()
		declare RESULT=""
		if [ "$LINE_TOTAL" -ge 3 ]; then
			declare -i i=0
			for (( LINE_COUNTER=1; LINE_COUNTER<="$LINE_TOTAL"; LINE_COUNTER++ )); do
# !!!
echo "$i"
				i=($i+1)
				declare -i LINE_CURRENT=($LINE_COUNTER+2)
				if [ "$LINE_CURRENT" -le "$LINE_TOTAL" ]; then
					LINE_CURRENT=($LINE_COUNTER+0)
					NODE_SECRET_KEY=$(echo "$NODE_RESPONSE" | sed "${LINE_CURRENT}!d" | grep -w "Secret key:")
					LINE_CURRENT=($LINE_COUNTER+1)
					NODE_PUBLIC_KEY=$(echo "$NODE_RESPONSE" | sed "${LINE_CURRENT}!d" | grep -w "Public key:")
					LINE_CURRENT=($LINE_COUNTER+2)
					NODE_ADDRESS=$(echo "$NODE_RESPONSE" | sed "${LINE_CURRENT}!d" | grep -w "Address:")
					if ! [ -z "$NODE_SECRET_KEY" ] && ! [ -z "$NODE_PUBLIC_KEY" ] && ! [ -z "$NODE_ADDRESS" ]; then
# !!!
echo "$NODE_SECRET_KEY"
echo "$NODE_PUBLIC_KEY"
echo "$NODE_ADDRESS"
					fi
					unset NODE_ADDRESS
					unset NODE_PUBLIC_KEY
					unset NODE_SECRET_KEY
				else
# !!!
echo "unknow error in output lines count"
				fi
				unset LINE_CURRENT
				LINE_COUNTER=($LINE_COUNTER+2)
			done
			unset LINE_COUNTER
		else
# !!!
echo "not 3 lines ?!"
		fi

# !!!
<< 'MULTILINE-COMMENT'

		for KEYS in "${RESULTS[@]}"; do
#			echo "$KEYS"
			declare NODE_WALLET=$(echo "$KEYS" | grep -w "Address" | awk '{ print $2 }')
			if [ -z "$RESULT" ]; then
				declare NODE_BALANCE=$(echo "$KEYS" | grep -w "Final balance" | awk '{ print $3 }')
				declare NODE_ROLLS_ACTIVE=$(echo "$KEYS" | grep -w "Active rolls" | awk '{ print $3 }')
				declare NODE_ROLLS_FINAL=$(echo "$KEYS" | grep -w "Final rolls" | awk '{ print $3 }')
				declare NODE_ROLLS_CANDIDATE=$(echo "$KEYS" | grep -w "Candidate rolls" | awk '{ print $3 }')
				if [ -z "$NODE_BALANCE" ]; then NODE_BALANCE="0"; fi
				if [ -z "$NODE_ROLLS_ACTIVE" ]; then NODE_ROLLS_ACTIVE="0"; fi
				if [ -z "$NODE_ROLLS_FINAL" ]; then NODE_ROLLS_FINAL="0"; fi
				if [ -z "$NODE_ROLLS_CANDIDATE" ]; then NODE_ROLLS_CANDIDATE="0"; fi
				if [ "$NODE_ROLLS_ACTIVE" -ne "0" ] || [ "$NODE_ROLLS_FINAL" -ne "0" ] || [ "$NODE_ROLLS_CANDIDATE" -ne "0" ] || [ "$NODE_BALANCE" -gt "0" ]; then
					if [ "$NODE_ROLLS_ACTIVE" -eq "1" ] && [ "$NODE_ROLLS_FINAL" -eq "1" ] && [ "$NODE_ROLLS_CANDIDATE" -eq "1" ]; then
						RESULT="'OK'"
					else
						RESULT="'ERROR'"
					fi
					TEXT+=("WALLET (ADDRESS): '$NODE_WALLET'")
					TEXT+=("BALANCE (FINAL): '$NODE_BALANCE'")
					TEXT+=("ROLLS (ACTIVE / FINAL / CANDIDATE): '$NODE_ROLLS_ACTIVE' / '$NODE_ROLLS_FINAL' / '$NODE_ROLLS_CANDIDATE'")
				fi
				unset NODE_ROLLS_CANDIDATE
				unset NODE_ROLLS_FINAL
				unset NODE_ROLLS_ACTIVE
				unset NODE_BALANCE
			fi
			NODE_WALLETS+=("$NODE_WALLET")
			unset NODE_WALLET
			unset KEYS
		done
MULTILINE-COMMENT
#		LOG "\e[34m [INFO] IP: '$NODE_IP'.\e[39m"
		if ! [ -z "$RESULT" ]; then
			for LINE in "${TEXT[@]}"; do
				if [ "$RESULT" == "'OK'" ]; then
					LOG "\e[32m [RESULT]	$LINE\.\e[39m"
				fi
				if [ "$RESULT" == "'ERROR'" ]; then
					LOG "\e[31m [ERROR]	$LINE\.\e[39m"
				fi
				unset LINE
			done
		else
			LOG "\e[31m [ERROR] NOT FOUND ACTIVE ROLLS OR TOKENS ON BALANCE.\e[39m"
			for NODE_WALLET in "${NODE_WALLETS[@]}"; do
				LOG "\e[31m [ERROR]	WALLET (ADDRESS): '$NODE_WALLET'.\e[39m"
			done
		fi
		unset NODE_WALLETS
		unset TEXT
		unset RESULT
# !!!
#		unset RESULTS
	else
		LOG "\e[31m [ERROR] NO RESPONSE FROM NODE CLIENT.\e[39m"
	fi
### Remove variables:
	unset NODE_RESPONSE
	unset NODE_PASSWORD
	unset NODE_IP
	unset NODE_PATH
	unset HOME_PATH
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
		-u|--update)
			SCRIPT_ACTION="UPDATE"
			shift
		;;
		-x|--uninstall)
			SCRIPT_ACTION="UNINSTALL"
			shift
		;;
		-r|--restart)
			SCRIPT_ACTION="RESTART"
			shift
		;;
		-w|--wallet)
			SCRIPT_ACTION="WALLET-REGISTER"
			shift
		;;
		-a|--activate)
			SCRIPT_ACTION="WALLET-ACTIVATE"
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
			echo "ERROR: UNKNOWN OPTION '$i'."
			echo "USAGE: "
			echo "		-i, --install"
			echo "			INSTALL 'MASSA' NODE"
			echo "		-u, --update"
			echo "			UPDATE 'MASSA' NODE"
			echo "		-x, --uninstall"
			echo "			UNINSTALL 'MASSA' NODE"
			echo "		-r, --restart"
			echo "			RESTART 'MASSA' NODE"
			echo "		-wr, --wallet-register"
			echo "			REGISTER 'MASSA' NODE WALLET"
			echo "		-wa, --wallet-activate"
			echo "			ACTIVATE 'MASSA' NODE WALLET"
			echo "		-s, --statistics"
			echo "			SHOW STATISTICS OF 'MASSA' NODE"
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
if [ "$SCRIPT_ACTION" == "INSTALL" ] || [ "$SCRIPT_ACTION" == "UPDATE" ] || [ "$SCRIPT_ACTION" == "UNINSTALL" ] || [ "$SCRIPT_ACTION" == "RESTART" ] || [ "$SCRIPT_ACTION" == "WALLET-REGISTER" ] || [ "$SCRIPT_ACTION" == "WALLET-ACTIVATE" ] || [ "$SCRIPT_ACTION" == "STATISTICS" ]; then
	LOG "\e[34m [INFO] STARTING...\e[39m"
	if [ "$(whoami)" != "root" ]; then
		LOG "\e[33m [WARNING] RUNNING AS '$(id -un)'...\e[39m"
#       	 LOG "\e[34m [INFO] AUTHORIZING AS ROOT USER...\e[39m"
#		sudo su -
	fi
	LOG "\e[34m [INFO] SERVER IP: '$IP'.\e[39m"
### Install "Massa" node:
	if [ "$SCRIPT_ACTION" == "INSTALL" ]; then
### Check necessary ports:
		declare TEST=""
		for PORT in "${PORTS[@]}"; do
			if [ -z "$TEST" ]; then
				TEST=$(ss -tulpen | awk '{print $5}' | grep ":$PORT$")
				if ! [ -z "$TEST" ]; then
					LOG "\e[31m [ERROR] INSTALLATION ON PORT '$PORT' IS NOT POSSIBLE, PORT IS ALREADY IN USE.\e[39m"
				fi
			fi
		done
		unset PORT
### Execute all functions:
		if [ -z "$TEST" ]; then
			LOG "\e[34m [INFO] INSTALLING 'MASSA'...\e[39m"

#		if [ -z "$DATABASE_IP" ]; then
#			LOG "\e[31m [ERROR] SERVER IP "$IP" NOT FOUND IN DATABASE FILE. CAN NOT CONTINUE.\e[39m"
#		fi
#		unset DATABASE_FILE
#		unset DATABASE_IP
#	else
#		LOG "\e[31m [ERROR] DATABASE FILE "$DATABASE_FILEPATH/$DATABASE_FILENAME" NOT FOUND. CAN NOT CONTINUE.\e[39m"
#	fi
#			SYSTEM
### Opening only primary port (not RPC):
#			PORTS "$PORTS"
#			NODE_INSTALL "$DATABASE_PORT" "$DATABASE_RPC" "$DOCKER_FILEPATH" "$DOCKER_FILENAME" "$DOCKER_IMAGENAME" "$DOCKER_CONTAINERNAME" "$DOCKER_DATAPATH"
#			NODE_ACTIVATE "$DATABASE_RPC" "${DATABASE_VALUES[$i]}"
#		else
#			NODE_STATISTICS "$DATABASE_RPC" "${DATABASE_VALUES[$i]}"
		fi
		unset TEST
### Update "Massa" node:
	elif [ "$SCRIPT_ACTION" == "UPDATE" ]; then
		LOG "\e[34m [INFO] UPDATING 'MASSA'...\e[39m"
		NODE_UPDATE "$HOME_PATH" "$NODE_PATH" "$BACKUP_PATH" "$IP" "$PASSWORD"

<< 'MULTILINE-COMMENT'

### Based on:
### https://github.com/SecorD0/Massa/blob/main/multi_tool.sh

replace_bootstraps() {
	local config_path="$HOME/massa/massa-node/base_config/config.toml"
	local bootstrap_list=`wget -qO- https://raw.githubusercontent.com/SecorD0/Massa/main/bootstrap_list.txt | shuf -n42 | awk '{ print "        "$0"," }'`
	local len=`wc -l < "$config_path"`
	local start=`grep -n bootstrap_list "$config_path" | cut -d: -f1`
	local end=`grep -n "\[optionnal\] port on which to listen" "$config_path" | cut -d: -f1`
	local end=$((end-1))
	local first_part=`sed "${start},${len}d" "$config_path"`
	local second_part=`cat <<EOF
    bootstrap_list = [
        ["149.202.86.103:31245", "P12UbyLJDS7zimGWf3LTHe8hYY67RdLke1iDRZqJbQQLHQSKPW8j"],
        ["149.202.89.125:31245", "P12vxrYTQzS5TRzxLfFNYxn6PyEsphKWkdqx2mVfEuvJ9sPF43uq"],
        ["158.69.120.215:31245", "P12rPDBmpnpnbECeAKDjbmeR19dYjAUwyLzsa8wmYJnkXLCNF28E"],
        ["158.69.23.120:31245", "P1XxexKa3XNzvmakNmPawqFrE9Z2NFhfq1AhvV1Qx4zXq5p1Bp9"],
        ["198.27.74.5:31245", "P1qxuqNnx9kyAMYxUfsYiv2gQd5viiBX126SzzexEdbbWd2vQKu"],
        ["198.27.74.52:31245", "P1hdgsVsd4zkNp8cF1rdqqG6JPRQasAmx12QgJaJHBHFU1fRHEH"],
        ["54.36.174.177:31245", "P1gEdBVEbRFbBxBtrjcTDDK9JPbJFDay27uiJRE3vmbFAFDKNh7"],
        ["51.75.60.228:31245", "P13Ykon8Zo73PTKMruLViMMtE2rEG646JQ4sCcee2DnopmVM3P5"],
${bootstrap_list}
    ]
EOF`
	local third_part=`sed "1,${end}d" "$config_path"`
	echo -e "${first_part}\n${second_part}\n${third_part}" > "$config_path"
	sed -i -e "s%retry_delay *=.*%retry_delay = 10000%; " "$config_path"
	printf_n "${C_LGn}Done!${RES}"
	if sudo systemctl status massad 2>&1 | grep -q running; then
		sudo systemctl restart massad
		printf_n "
You can view the node bootstrapping via ${C_LGn}massa_log${RES} command
"
	fi	
}

MULTILINE-COMMENT

### Unistall "Massa" node:
	elif [ "$SCRIPT_ACTION" == "UNINSTALL" ]; then
		LOG "\e[34m [INFO] UNINSTALLING 'MASSA'...\e[39m"
#		NODE_UNINSTALL
<< 'MULTILINE-COMMENT'

### Based on:
### https://github.com/SecorD0/Massa/blob/main/multi_tool.sh

uninstall() {
	sudo systemctl stop massad
	if [ ! -d $HOME/massa_backup ]; then
		mkdir $HOME/massa_backup
		sudo cp $HOME/massa/massa-client/wallet.dat $HOME/massa_backup/wallet.dat
		sudo cp $HOME/massa/massa-node/config/node_privkey.key $HOME/massa_backup/node_privkey.key
	fi
	if [ -f $HOME/massa_backup/wallet.dat ] && [ -f $HOME/massa_backup/node_privkey.key ]; then
		rm -rf $HOME/massa/ /etc/systemd/system/massa.service /etc/systemd/system/massad.service
		sudo systemctl daemon-reload
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n massa_log -da
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n massa_client -da
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n massa_cli_client -da
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n massa_node_info -da
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n massa_wallet_info -da
		. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n massa_buy_rolls -da
		printf_n "${C_LGn}Done!${RES}"
	else
		printf_n "${C_LR}No backup of the necessary files was found, delete the node manually!${RES}"
	fi	
}

MULTILINE-COMMENT
### Restart "Massa" node:
	elif [ "$SCRIPT_ACTION" == "RESTART" ]; then
		LOG "\e[34m [INFO] RESTARTING 'MASSA'...\e[39m"
#		NODE_RESTART
### Registering "Massa" node wallet:
	elif [ "$SCRIPT_ACTION" == "WALLET-REGISTER" ]; then
		LOG "\e[34m [INFO] REGISTERING 'MASSA' NODE WALLET...\e[39m"
#		NODE_WALLET_REGISTER
### Activate "Massa" node wallet:
	elif [ "$SCRIPT_ACTION" == "WALLET-ACTIVATE" ]; then
		LOG "\e[34m [INFO] ACTIVATING 'MASSA' NODE WALLET...\e[39m"
#		NODE_WALLET_ACTIVATE
### Show statistics of "Massa" node:
	elif [ "$SCRIPT_ACTION" == "STATISTICS" ]; then
		LOG "\e[34m [INFO] 'MASSA' STATISTICS...\e[39m"
		NODE_STATISTICS "$HOME_PATH" "$NODE_PATH" "$IP" "$PASSWORD"
	fi
	LOG "\e[34m [INFO] DONE.\e[39m"
else
	LOG "\e[31m [ERROR] UNKNOWN SCRIPT ACTION '$SCRIPT_ACTION'. CAN NOT CONTINUE.\e[39m"
fi
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
unset SCRIPT_LOG_COLOR
unset SCRIPT_ACTION
unset DATABASE_DELIMITER
unset DATABASE_FILENAME
unset DATABASE_FILEPATH
unset BACKUP_PATH
unset NODE_PATH
unset HOME_PATH
unset IP
### -------------------------------------------------------------------------------------------------
