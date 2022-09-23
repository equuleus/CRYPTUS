#!/bin/bash
### -------------------------------------------------------------------------------------------------
# COPYRIGHT: EQUULEUS [https://github.com/equuleus]
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
clear
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set ports wich we want to remove from permissions lists:
declare -a PORT_LIST=("80" "6180" "6181" "6182" "9101")
### Set aliases to remove "APTOS_NODENAME" and "WORKSPACE":
declare -a BASH_PROFILE_LIST=("APTOS_NODENAME" "WORKSPACE")
### Set project home directory:
declare HOME_DIRECTORY="$HOME/.aptos"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
if [ -d "$HOME_DIRECTORY" ] && [ ! -L "$HOME_DIRECTORY" ]; then
	cd "$HOME_DIRECTORY"
### Turn off Docker Compose:
	sudo docker-compose down -v
fi
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Stop APTOS Docker Compose Service:
sudo systemctl stop docker-compose-aptos >/dev/null 2>&1
### Disable APTOS Docker Compose Service:
sudo systemctl disable docker-compose-aptos >/dev/null 2>&1
### Remove APTOS Docker Compose Service from system dicrectory:
sudo rm -f /etc/systemd/system/docker-compose-aptos.service >/dev/null 2>&1
### Restart and reload system service:
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Stop and remove Docker container if exists:
if ! [ -z '$(sudo docker container list 2>/dev/null | grep -w "aptos-validator-1")' ]; then
	sudo docker rm -f "aptos-validator-1" >/dev/null 2>&1
fi
### Remove Docker image/container if exists:
# if ! [ -z '$(sudo docker container list 2>/dev/null | grep -w "aptoslabs/validator:testnet")' ]; then
#	sudo docker rmi -f "aptoslabs/validator:testnet" >/dev/null 2>&1
# fi
### Print current lists of containers and images:
# sudo docker container list
# sudo docker images list
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Remove APTOS binary file:
if [ -f "/usr/local/bin/aptos" ]; then
	sudo rm -f /usr/local/bin/aptos >/dev/null 2>&1
fi
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Read current firewall configuration:
declare FIREWALL_COMMAND=$(sudo ufw status | grep -v '^\s*$' | tail -n +4)
### Make a list from all lines:
IFS=$'\n' read -rd "" -a FIREWALL_RESULT <<< "$FIREWALL_COMMAND"
### Check all lines of firewall configuration to match with our ports:
for FIREWALL_RULE_FULL in "${FIREWALL_RESULT[@]}"; do
	declare FIREWALL_RULE_NAME=""
### Check all our ports:
	for FIREWALL_PORT in "${PORT_LIST[@]}"; do
### Check match our port with firewall rule line:
		declare FIREWALL_RULE_LINE=$(echo "$FIREWALL_RULE_FULL" | grep -w "$FIREWALL_PORT")
### If result is not empty:
		if ! [ -z "$FIREWALL_RULE_LINE" ]; then
			declare FIREWALL_RULE_VALUE_1=$(echo $FIREWALL_RULE_LINE | awk '{ print $1 }')
			declare FIREWALL_RULE_VALUE_2=$(echo $FIREWALL_RULE_LINE | awk '{ print $2 }')
### Check if it "(v6)" or not:
			if [ "$FIREWALL_RULE_VALUE_2" == "(v6)" ]; then
				FIREWALL_RULE_NAME="$FIREWALL_RULE_VALUE_1 $FIREWALL_RULE_VALUE_2"
			else
				FIREWALL_RULE_NAME="$FIREWALL_RULE_VALUE_1"
			fi
			unset FIREWALL_RULE_VALUE_2
			unset FIREWALL_RULE_VALUE_1
		fi
		unset FIREWALL_RULE_LINE
		unset FIREWALL_PORT
	done
### If we got a name of a rule, run command to remove it:
	if ! [ -z "$FIREWALL_RULE_NAME" ]; then
### Remove ports from firewall:
		sudo ufw delete allow "$FIREWALL_RULE_NAME" >/dev/null 2>&1
	fi
	unset FIREWALL_RULE_NAME
	unset FIREWALL_RULE_FULL
done
unset FIREWALL_RESULT
unset FIREWALL_COMMAND
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Check if "IPTables" is installed:
IPTABLES=$(apt list --installed 2>/dev/null | grep -w "iptables") >/dev/null 2>&1
if ! [ -z "${IPTABLES}" ]; then
### If it is installed, - run command to remove rule with our port:
	for IPTABLES_PORT in "${PORT_LIST[@]}"; do
### Remove ports from "IPTables":
		sudo iptables -D INPUT -p tcp --dport "$IPTABLES_PORT" -j ACCEPT >/dev/null 2>&1
		unset IPTABLES_PORT
	done
	if [ -d "/etc/iptables" ] && [ ! -L "/etc/iptables" ]; then
		sudo iptables-save > /etc/iptables/rules.v4
		sudo ip6tables-save > /etc/iptables/rules.v6
	fi
fi
unset IPTABLES
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Remove data from ".bash_profile":
for BASH_PROFILE_NAME in "${BASH_PROFILE_LIST[@]}"; do
	sed -i "/ ${BASH_PROFILE_NAME}=/d" $HOME/.bash_profile
	unset "$BASH_PROFILE_NAME"
	unalias "$BASH_PROFILE_NAME" 2>/dev/null
	unset BASH_PROFILE_NAME
done
sed -i '/^$/d' $HOME/.bash_profile
. $HOME/.bash_profile
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Remove project home directory (recursive):
if [ -d "$HOME_DIRECTORY" ]; then
	cd $HOME
	sudo rm -rf "$HOME_DIRECTORY" >/dev/null 2>&1
fi
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Remove variables:
unset HOME_DIRECTORY
unset BASH_PROFILE_LIST
unset PORT_LIST
### -------------------------------------------------------------------------------------------------
