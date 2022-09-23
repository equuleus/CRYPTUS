#!/bin/bash

### -------------------------------------------------------------------------------------------------
### Path to SSH RSA Private and Public keys:
SSH_FILEPATH="/home/$(id -un)/.ssh"
### Filename of SSH RSA Private key (Public key will automatically has name "$SSH_FILENAME.pub"):
SSH_FILENAME="id_rsa"
### Set the SSH private key passphrase for generate and operate (you can set an empty value for no passphrase input requests, but it less secure):
SSH_KEY_PASSPHRASE="CRYPTUS"
# SSH_KEY_PASSPHRASE=""
### Force a private key to connect to SSH instead of a password (if a passphrase is set, it will ask you before connecting):
#SSH_FORCE_KEY_AUTH=true
SSH_FORCE_KEY_AUTH=false
### Set file path and file name with contents of servers, usernames and password:
DATABASE_FILEPATH="$PWD"
DATABASE_FILENAME="servers.txt"
DATABASE_DELIMITER="|"
### Path to Ansible configuration files:
ANSIBLE_FILEPATH="../ANSIBLE"
# ANSIBLE_FILEPATH="/home/$(id -un)"
### Filenames of Ansible configuration files:
ANSIBLE_FILENAME_INVENTORY="ansible-hosts.ini"
ANSIBLE_FILENAME_PLAYBOOK="ansible-setup.yml"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Clear console screen:
clear
### -------------------------------------------------------------------------------------------------
### --- LOG -----------------------------------------------------------------------------------------
function SERVERS_LOG() {
	declare TEXT="${1}"
	declare DATE=$(date +"[%Y-%m-%d] [%H:%M:%S]")
	echo "$DATE $TEXT"
	unset DATE
	unset TEXT
}
### -------------------------------------------------------------------------------------------------
### --- Select Answer -------------------------------------------------------------------------------
function SERVERS_SELECT_ANSWER() {
### Get input variables:
	declare TEXT_QUESTION="${1}"
	declare TEXT_Y="${2}"
	declare TEXT_N="${3}"
### Select answer for question:
	declare ANSWER=""
	while true; do
		declare DATE=$(date +"[%Y-%m-%d] [%H:%M:%S]")
		read -p "$DATE $TEXT_QUESTION [y/n]: " ANSWER
		unset DATE
		case $ANSWER in
			[Yy] )
#			[Yy]* )
				SERVERS_LOG "Selected \"Yes\"."
				if ! [ -z "${TEXT_Y}" ]; then
					SERVERS_LOG "$TEXT_Y"
				fi
				printf "\n"
				break
			;;
			[Nn] )
#			[Nn]* )
				SERVERS_LOG "Selected \"No\"."
				if ! [ -z "${TEXT_N}" ]; then
					SERVERS_LOG "$TEXT_N"
				fi
				printf "\n"
				break
#				exit
			;;
			* ) SERVERS_LOG "Input is uncorrect. Please answer yes (\"Y\") or no (\"N\")...";;
		esac
	done
### Remove variable and return result:
	if [ $ANSWER == "Y" ] || [ $ANSWER == "y" ]; then
		unset ANSWER
		true
		return
	else 
		unset ANSWER
		false
		return
	fi
}
### -------------------------------------------------------------------------------------------------
### --- Update --------------------------------------------------------------------------------------
function SERVERS_UPDATE() {
### Get input variables:
	declare SERVER_HOST="${1}"
	declare SERVER_PORT="${2}"
	declare SERVER_USERNAME="${3}"
	declare SERVER_PASSWORD="${4}"
	declare SSH_OPTIONS="${5}"
	declare TEXT_START="Updating system packages"
	declare TEXT_FINISH="Update complete"
### Update system packages from internet repository:
	if [ -z "${SERVER_HOST}" ]; then
		SERVERS_LOG "$TEXT_START on localhost..."
		sudo apt update >/dev/null 2>&1
		SERVERS_LOG "$TEXT_FINISH on localhost."
		printf "\n"
	else
		SERVERS_LOG "$TEXT_START on \"$SERVER_HOST\"..."
		echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S apt update >/dev/null 2>&1"
		SERVERS_LOG "$TEXT_FINISH on \"$SERVER_HOST\"."
	fi
### Remove variables:
	unset TEXT_FINISH
	unset TEXT_START
	unset SSH_OPTIONS
	unset SERVER_PASSWORD
	unset SERVER_USERNAME
	unset SERVER_PORT
	unset SERVER_HOST
}
### -------------------------------------------------------------------------------------------------
### --- SSH server ----------------------------------------------------------------------------------
function SERVERS_SSH_SERVER() {
### Check if installed SSH server:
	SERVERS_LOG "Checking SSH server installation and run..."
### Check if package is installed:
	declare SSH=$(sudo apt list --installed 2>/dev/null | grep -w "openssh-server") >/dev/null 2>&1
#	declare SSH=$(sudo apt-cache pkgnames | grep -w "openssh-server") >/dev/null 2>&1
	if [ -z "${SSH}" ]; then
		SERVERS_LOG "SSH server is not installed. Trying to install, please wait..."
### Install SSH server (if not installed) from internet repository:
		sudo apt install openssh-server -y >/dev/null 2>&1
		sleep 1
		SSH=$(sudo apt list --installed 2>/dev/null | grep -w "openssh-server") >/dev/null 2>&1
		if [ -z "${SSH}" ]; then
			SERVERS_LOG "ERROR: SSH server was not installed."
			sleep 3
		else
### Enable auto-start serice of SSH server:
			sudo systemctl enable ssh >/dev/null 2>&1
			SERVERS_LOG "SSH server was installed."
		fi
	else
		SERVERS_LOG "SSH server is already installed."
	fi
### Remove variable:
	unset SSH
	declare SSH=$(sudo service ssh status | grep -w "Active:" | grep -w "(running)") >/dev/null 2>&1
	if [ -z "${SSH}" ]; then
### Start serice of SSH server:
		sudo systemctl start ssh >/dev/null 2>&1
#		sudo service ssh start >/dev/null 2>&1
		sleep 1
		SSH=$(sudo service ssh status | grep -w "Active:" | grep -w "(running)") >/dev/null 2>&1
		if [ -z "${SSH}" ]; then
			SERVERS_LOG "ERROR: Can not start SSH server service."
			sleep 3
		else
			SERVERS_LOG "SSH server service was started."
		fi
	else
		SERVERS_LOG "SSH server service is already started."
	fi
### Remove variable:
	unset SSH
### Check serice status of SSH server:
#	sudo service ssh status
	printf "\n"
}
### -------------------------------------------------------------------------------------------------
### --- Firewall ------------------------------------------------------------------------------------
function SERVERS_FIREWALL() {
### Get input variables:
	declare SERVER_HOST="${1}"
	declare SERVER_PORT="${2}"
	declare SERVER_USERNAME="${3}"
	declare SERVER_PASSWORD="${4}"
	declare SSH_OPTIONS="${5}"
### Check if SSH port is open on firewall:
	declare TEXT="Checking firewall SSH rule and status"
	declare FIREWALL=""
	if [ -z "${SERVER_HOST}" ]; then
		SERVERS_LOG "$TEXT on localhost..."
		FIREWALL=$(sudo ufw status | grep -w "ALLOW" | grep -w "OpenSSH") >/dev/null 2>&1
	else
		SERVERS_LOG "$TEXT on \"$SERVER_HOST\"..."
		FIREWALL=$(echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S ufw status 2>/dev/null | grep -w \"ALLOW\" | grep -w \"OpenSSH\"") >/dev/null 2>&1
	fi
	unset TEXT
	declare TEXT=""
	if [ -z "${FIREWALL}" ]; then
### Add rules to firewall:
		if [ -z "${SERVER_HOST}" ]; then
			sudo ufw allow "OpenSSH" >/dev/null 2>&1
#			sudo ufw allow ssh >/dev/null 2>&1
#			sudo ufw allow port 22 proto tcp comment 'Allow access SSH port' >/dev/null 2>&1
### Remove allow rule:
#			sudo ufw delete allow 22/tcp >/dev/null 2>&1
			FIREWALL=$(sudo ufw status | grep -w "ALLOW" | grep -w "OpenSSH") >/dev/null 2>&1
		else
			echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S ufw allow \"OpenSSH\" >/dev/null 2>&1"
			FIREWALL=$(echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S ufw status 2>/dev/null | grep -w \"ALLOW\" | grep -w \"OpenSSH\"") >/dev/null 2>&1
		fi
### Combine information message:
		if [ -z "${FIREWALL}" ]; then
			TEXT="ERROR: Can not enable rule on firewall (possibly disabled) for SSH port"
			sleep 3
		else
			TEXT="SSH port on firewall was enabled"
		fi
		if [ -z "${SERVER_HOST}" ]; then
			SERVERS_LOG "$TEXT on localhost."
		else
			SERVERS_LOG "$TEXT on \"$SERVER_HOST\"."
		fi
	else
		TEXT="SSH port is already enabled on firewall"
		if [ -z "${SERVER_HOST}" ]; then
			SERVERS_LOG "$TEXT on localhost."
		else
			SERVERS_LOG "$TEXT on \"$SERVER_HOST\"."
		fi
	fi
### Remove variables:
	unset FIREWALL
	unset TEXT
	declare TEXT=""
	declare FIREWALL=""
### Check if firewall is enabled:
	if [ -z "${SERVER_HOST}" ]; then
		FIREWALL=$(sudo ufw status | grep -w "Status:" | grep -w "active") >/dev/null 2>&1
	else
		FIREWALL=$(echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S ufw status 2>/dev/null | grep -w \"Status:\" | grep -w \"active\"") >/dev/null 2>&1
	fi
	if [ -z "${FIREWALL}" ]; then
### Enable firewall:
		if [ -z "${SERVER_HOST}" ]; then
			sudo ufw --force enable >/dev/null 2>&1
		else
			echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S ufw --force enable >/dev/null 2>&1"
		fi
		sleep 1
		if [ -z "${SERVER_HOST}" ]; then
			FIREWALL=$(sudo ufw status | grep -w "Status:" | grep -w "active") >/dev/null 2>&1
			TEXT="on localhost."
		else
			FIREWALL=$(echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S ufw status 2>/dev/null | grep -w \"Status:\" | grep -w \"active\"") >/dev/null 2>&1
			TEXT="on \"$SERVER_HOST\"."
		fi
		if [ -z "${FIREWALL}" ]; then
			SERVERS_LOG "ERROR: Can not enable Firewall $TEXT"
			sleep 3
		else
			SERVERS_LOG "Firewall was enabled $TEXT"
		fi
	else
		TEXT="Firewall is already enabled"
### Reload firewall with new rules (not needed):
		if [ -z "${SERVER_HOST}" ]; then
			SERVERS_LOG "$TEXT on localhost."
#			sudo ufw reload >/dev/null 2>&1
		else
			SERVERS_LOG "$TEXT on \"$SERVER_HOST\"."
#			echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S ufw reload >/dev/null 2>&1"
		fi
	fi
	if [ -z "${SERVER_HOST}" ]; then
### Check firewall status:
#		sleep 1
#		sudo ufw status
		printf "\n"
	fi
### Remove variables:
	unset FIREWALL
	unset TEXT
	unset SSH_OPTIONS
	unset SERVER_PASSWORD
	unset SERVER_USERNAME
	unset SERVER_PORT
	unset SERVER_HOST
}
### -------------------------------------------------------------------------------------------------
### --- Ansible -------------------------------------------------------------------------------------
function SERVERS_ANSIBLE() {
### Get input variables:
	declare SERVER_HOST="${1}"
	declare SERVER_PORT="${2}"
	declare SERVER_USERNAME="${3}"
	declare SERVER_PASSWORD="${4}"
	declare SSH_OPTIONS="${5}"
### Check if installed Ansible (package is installed):
	declare TEXT="Checking Ansible installation"
	declare ANSIBLE=""
	if [ -z "${SERVER_HOST}" ]; then
		SERVERS_LOG "$TEXT on localhost..."
		ANSIBLE=$(sudo apt list --installed 2>/dev/null | grep -w "ansible") >/dev/null 2>&1
	else
		SERVERS_LOG "$TEXT on \"$SERVER_HOST\"..."
		ANSIBLE=$(echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S apt list --installed 2>/dev/null | grep -w \"ansible\"")
	fi
	unset TEXT
	declare TEXT=""
#	declare ANSIBLE=$(sudo apt-cache pkgnames | grep -w "ansible") >/dev/null 2>&1
	if [ -z "${ANSIBLE}" ]; then
### Install Ansible (if not installed) from internet repository (on local or remote server if "$SERVER_HOST" is set):
		SERVERS_LOG "Ansible is not installed. Trying to install, please wait..."
		if [ -z "${SERVER_HOST}" ]; then
			sudo apt install ansible -y >/dev/null 2>&1
			sleep 1
			ANSIBLE=$(sudo apt list --installed 2>/dev/null | grep -w "ansible") >/dev/null 2>&1
		else
			echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S apt install ansible -y >/dev/null 2>&1"
			sleep 1
			ANSIBLE=$(echo $SERVER_PASSWORD | sshpass -p $SERVER_PASSWORD ssh $SERVER_HOST -l $SERVER_USERNAME -p $SERVER_PORT -T $SSH_OPTIONS "sudo -S apt list --installed 2>/dev/null | grep -w \"ansible\"")
		fi
### Combine information message:
		if [ -z "${ANSIBLE}" ]; then
			TEXT="ERROR: Ansible was not installed"
			sleep 3
		else
			TEXT="Ansible was successfully installed"
		fi
		if [ -z "${SERVER_HOST}" ]; then
			SERVERS_LOG "$TEXT on localhost."
		else
			SERVERS_LOG "$TEXT on \"$SERVER_HOST\"."
		fi
	else
		TEXT="Ansible is already installed"
		if [ -z "${SERVER_HOST}" ]; then
			SERVERS_LOG "$TEXT on localhost."
		else
			SERVERS_LOG "$TEXT on \"$SERVER_HOST\"."
		fi
	fi
	if [ -z "${SERVER_HOST}" ]; then
		printf "\n"
	fi
### Remove variables:
	unset TEXT
	unset ANSIBLE
	unset SSH_OPTIONS
	unset SERVER_PASSWORD
	unset SERVER_USERNAME
	unset SERVER_PORT
	unset SERVER_HOST
}
### -------------------------------------------------------------------------------------------------
### --- SSH Add Start -------------------------------------------------------------------------------
function SERVERS_SSH_ADD_START() {
	declare SSH_FILEPATH="${1}"
	declare SSH_FILENAME="${2}"
	declare SSH_KEY_PASSPHRASE="${3}"
### Removing any saved passphrases and stopping SSH Agent service (to start new one) if environment variables of SSH Agent was found:
	if [ -z "$SSH_AUTH_SOCK" ] ; then
		ssh-add -D > /dev/null 2>&1
		ssh-agent -k > /dev/null 2>&1
	fi
### Start new SSH Agent service to make ssh connection with private key without any passphrase promt:
	eval $(ssh-agent -s) > /dev/null 2>&1
	if ! [ -z "${SSH_KEY_PASSPHRASE}" ]; then
### Or you can use some of external utilities to automate it: https://unix.stackexchange.com/questions/640905/skip-password-prompt-and-pass-password-to-ssh-add-in-script
		echo "Please input your password (\"$SSH_KEY_PASSPHRASE\") for RSA private key. If it not work, you should make new SSH key pair."
	fi
	unset SSH_KEY_PASSPHRASE
	ssh-add "$SSH_FILEPATH/$SSH_FILENAME"
	RESULT=$(diff <(ssh-add -l) <(ssh-keygen -l -f "$SSH_FILEPATH/$SSH_FILENAME"))
### Remove variable and return result:
	if [ -z "${RESULT}" ]; then
		unset RESULT
		true
		return
	else
		unset RESULT
		false
		return
	fi
	unset SSH_FILENAME
	unset SSH_FILEPATH
}
### -------------------------------------------------------------------------------------------------
### --- SSH Add Stop --------------------------------------------------------------------------------
function SERVERS_SSH_ADD_STOP() {
### Remove saved priavte keys:
	ssh-add -D > /dev/null 2>&1
### Stop SSH Agent:
	ssh-agent -k > /dev/null 2>&1
### Remove environment variables of SSH Agent:
	unset SSH_AGENT_PID
	unset SSH_AUTH_SOCK
}
### -------------------------------------------------------------------------------------------------
### --- SSH keys ------------------------------------------------------------------------------------
function SERVERS_SSH_DEPLOY() {
### Get input variables:
	declare SSH_FILEPATH="${1}"
	declare SSH_FILENAME="${2}"
	declare SSH_KEY_PASSPHRASE="${3}"
	declare SSH_FORCE_KEY_AUTH="${4}"
	declare DATABASE_FILEPATH="${5}"
	declare DATABASE_FILENAME="${6}"
	declare DATABASE_DELIMITER="${7}"
### Check if installed SSHPass:
	SERVERS_LOG "Checking SSH password automation installation..."
### Check if package is installed:
	declare SSH=$(sudo apt list --installed 2>/dev/null | grep -w "sshpass") >/dev/null 2>&1
#	declare SSH=$(sudo apt-cache pkgnames | grep -w "sshpass") >/dev/null 2>&1
	if [ -z "${SSH}" ]; then
### Install SSHPass (if not installed) from internet repository:
		SERVERS_LOG "SSHPass is not installed. Trying to install, please wait..."
		sudo apt install sshpass -y >/dev/null 2>&1
		sleep 1
		SSH=$(sudo apt list --installed 2>/dev/null | grep -w "sshpass") >/dev/null 2>&1
		if [ -z "${SSH}" ]; then
			SERVERS_LOG "ERROR: SSHPass was not installed."
			sleep 3
			exit
		else
			SERVERS_LOG "SSHPass was installed."
		fi
	else
		SERVERS_LOG "SSHPass is already installed."
	fi
### Remove variable:
	unset SSH
	printf "\n"
        SERVERS_LOG "Checking RSA files in \"$SSH_FILEPATH\"..."
### Get all files in "$SSH_FILEPATH":
	declare -a FILES_LIST
	for FILE_NAME in $(ls "$SSH_FILEPATH" 2>/dev/null); do
		if [ "${FILE_NAME:0:${#SSH_FILENAME}}" == "$SSH_FILENAME" ]; then
			if [ -f "$SSH_FILEPATH/$FILE_NAME" ]; then
			        SERVERS_LOG "Found file \"$SSH_FILEPATH/$FILE_NAME\"..."
				FILES_LIST+=($FILE_NAME)
			fi
		fi
	done
	unset FILE_NAME
### Set flag variable (generate or not new keys):
	declare RESULT
### Get count of elements in a array:
	declare -i FILES_COUNT="${#FILES_LIST[@]}"
	if [ "$FILES_COUNT" -gt "0" ]; then
		if [ "$FILES_COUNT" -gt "1" ]; then
		        SERVERS_LOG "Compare existing SSH keys (private with public)..."
			if [ -f "$SSH_FILEPATH/$SSH_FILENAME" ] && [ -f "$SSH_FILEPATH/$SSH_FILENAME.pub" ]; then
### This uses passphrase for test private key:
				declare SSH_KEYS=$(diff <(ssh-keygen -y -P "$SSH_KEY_PASSPHRASE" -f "$SSH_FILEPATH/$SSH_FILENAME" | cut -d" " -f 2) <(cut -d" " -f 2 "$SSH_FILEPATH/$SSH_FILENAME.pub"))
				if [ -z "${SSH_KEYS}" ]; then
					RESULT=false
				        SERVERS_LOG "SSH key files (\"${FILES_LIST[0]}\" and \"${FILES_LIST[1]}\") match."
				else
					RESULT=true
				        SERVERS_LOG "ERROR: SSH key files (\"${FILES_LIST[0]}\" and \"${FILES_LIST[1]}\") not match! Existing files (\"$SSH_FILEPATH/$SSH_FILENAME*\") will be removed and generated new pair of SSH keys."
					sleep 3
				fi
				unset SSH_KEYS
			else
				RESULT=true
				if ! [ -f "$SSH_FILEPATH/$SSH_FILENAME" ]; then
				        SERVERS_LOG "ERROR: SSH key file (private \"$SSH_FILEPATH/$SSH_FILENAME\") not found! Existing file will be removed and generated new pair of SSH keys."
				fi
				if ! [ -f "$SSH_FILEPATH/$SSH_FILENAME.pub" ]; then
				        SERVERS_LOG "ERROR: SSH key file (public \"$SSH_FILEPATH/$SSH_FILENAME.pub\") not found! Existing file will be removed and generated new pair of SSH keys."
				fi
				sleep 3
			fi
		else 
			RESULT=true
		        SERVERS_LOG "ERROR: only one file (\"${FILES_LIST[0]}\") of SSH pair keys (private and public) was found in a SSH directory! Existing file will be removed and generated new pair of SSH keys."
			sleep 3
		fi
		if [ "${RESULT}" == false ]; then
			SERVERS_SELECT_ANSWER "Remove $FILES_COUNT file(s) from \"$SSH_FILEPATH\" and generate new SSH keys?" "Removing current SSH keys and generating new pair..." "Using current SSH keys..."
			if [ $? == 0 ]; then
				SERVERS_SELECT_ANSWER "Please confirm deletion of $FILES_COUNT file(s) from \"$SSH_FILEPATH\" and generate new SSH keys:" "Removing current SSH keys and generating new pair..." "Using current SSH keys..."
				if [ $? == 0 ]; then
					RESULT=true
				else
					RESULT=false
				fi
			else
				RESULT=false
			fi
		fi
	else
		RESULT=true
	fi
	if [ "${RESULT}" == true ]; then
		if [ "$FILES_COUNT" -gt "0" ]; then
			SERVERS_LOG "Removing old SSH keys:"
			for FILE_NAME in "${FILES_LIST[@]}"; do
				SERVERS_LOG "Removing \"$FILE_NAME\"..."
				rm -f "$FILE_NAME" >/dev/null 2>&1
			done
			unset FILE_NAME
		fi
### Generate new SSH keys:
	        SERVERS_LOG "Generate new SSH keys..."
		ssh-keygen -q -t rsa -b 4096 -N "$SSH_KEY_PASSPHRASE" -f "$SSH_FILEPATH/$SSH_FILENAME" <<< $"\ny" >/dev/null 2>&1
### -q		Silence ssh-keygen.
### -t rsa	Specifies type of key to create (RSA).
### -b 4096	Specifies the number of bits in the key to create (4096 bits).
### -N ''		Provides the new passphrase (empty, in this case).
### -f filename	Specifies the filename of the key file.
### <<<		Part of shell: "here string" to feed a string into the stdin of ssh-keygen.
### $'\n'		A newline (using $ to make the single-quoted string interpret special characters).
	else
		SERVERS_LOG "Working with current SSH keys..."
	fi
	printf "\n"
### Remove variables:
	unset RESULT
	unset FILES_COUNT
	unset FILES_LIST
	declare SSH_OPTIONS=""
	declare RESULT=false
### If we want to connect with a private key, then start SSH Agent and add passphrase to it:
	if [ "${SSH_FORCE_KEY_AUTH}" == true ]; then
### Set options for SSH client connection:
		SSH_OPTIONS="-o StrictHostKeyChecking=no -o PreferredAuthentications=publickey"
		SERVERS_SSH_ADD_START "$SSH_FILEPATH" "$SSH_FILENAME" "$SSH_KEY_PASSPHRASE"
		if [ $? == 0 ]; then
			RESULT=true
		else
			RESULT=false
		fi
	else
### Set options for SSH client connection:
		SSH_OPTIONS="-o StrictHostKeyChecking=no -o PreferredAuthentications=password"
		RESULT=true
	fi
	if [ "${RESULT}" == true ]; then
	        SERVERS_LOG "SSH private key passphrase loaded successfully."
		declare SSH_KEY=$(cat "$SSH_FILEPATH/$SSH_FILENAME.pub") >/dev/null 2>&1
		declare -a DATABASE_ELEMENTS
		printf "\n"
	        SERVERS_LOG "Copying SSH keys to remote server(s)..."
### Loop through the database file:
		IFS=$'\n' read -rd "" -a DATABASE_FILE <<< $(cat "$DATABASE_FILEPATH/$DATABASE_FILENAME")
		for DATABASE_STRING in "${DATABASE_FILE[@]}"; do
### Removing all spaces (" "), then replacing all "||" to "|#|", then removing "|" from the end of the line, and then removing CR ("\r") from the line:
			DATABASE_STRING=$(echo "$DATABASE_STRING" | sed "s/ //g" | sed "s/${DATABASE_DELIMITER}${DATABASE_DELIMITER}/${DATABASE_DELIMITER}\#${DATABASE_DELIMITER}/g" | sed "s/${DATABASE_DELIMITER}$//" | sed "s/\r$//")
			declare -a DATABASE_VALUES=(${DATABASE_STRING//"$DATABASE_DELIMITER"/ })
### Check if line is not a comment:
			if [ "${DATABASE_VALUES[0]:0:1}" != "#" ]; then
### Connect with SSH to all serves in database file:
				SERVERS_LOG "--- ${DATABASE_VALUES[0]} ---"
				declare TEXT="Remote server host \"${DATABASE_VALUES[0]}\" result:"
				declare SSH_CONNECTION=$(ssh ${DATABASE_VALUES[0]} -p ${DATABASE_VALUES[1]} -T $SSH_OPTIONS -o BatchMode=yes -o ConnectTimeout=3 2>&1 | grep -w "timed out" 2>/dev/null)
				if [ -z "${SSH_CONNECTION}" ]; then
					SSH_CONNECTION=$(sshpass -p ${DATABASE_VALUES[3]} ssh ${DATABASE_VALUES[0]} -l ${DATABASE_VALUES[2]} -p ${DATABASE_VALUES[1]} -T $SSH_OPTIONS "date" 2>&1)
					SSH_REMOTE_HOST_IDENTIFICATION="ssh-keygen -f \"${SSH_FILEPATH}/known_hosts\" -R \"${DATABASE_VALUES[0]}\""
					declare SSH_REMOTE_HOST_CHECK=$(echo "${SSH_CONNECTION}" | grep -w "${SSH_REMOTE_HOST_IDENTIFICATION}")
					if ! [ -z "$SSH_REMOTE_HOST_CHECK" ]; then
						bash -c "$SSH_REMOTE_HOST_IDENTIFICATION" >/dev/null 2>&1
						SSH_REMOTE_HOST_IDENTIFICATION=$(echo "$SSH_REMOTE_HOST_IDENTIFICATION" | sed "s/\/home\/$(id -un)\/\.ssh/\/root\/\.ssh/g")
						sudo bash -c "$SSH_REMOTE_HOST_IDENTIFICATION" >/dev/null 2>&1
						SSH_CONNECTION=$(sshpass -p ${DATABASE_VALUES[3]} ssh ${DATABASE_VALUES[0]} -l ${DATABASE_VALUES[2]} -p ${DATABASE_VALUES[1]} -T $SSH_OPTIONS "date" 2>&1)
					fi
					unset SSH_REMOTE_HOST_CHECK
					unset SSH_REMOTE_HOST_IDENTIFICATION
					if ! [ -z "${SSH_CONNECTION}" ] && [ -z "$(echo \"${SSH_CONNECTION}\" | grep -w \"denied\")" ]; then
#						SERVERS_LOG "Server host: ${DATABASE_VALUES[0]}"
#						SERVERS_LOG "Server port: ${DATABASE_VALUES[1]}"
#						SERVERS_LOG "Server username: ${DATABASE_VALUES[2]}"
#						SERVERS_LOG "Server password: ${DATABASE_VALUES[3]}"
						declare SSH_KEYS=$(sshpass -p ${DATABASE_VALUES[3]} ssh ${DATABASE_VALUES[0]} -l ${DATABASE_VALUES[2]} -p ${DATABASE_VALUES[1]} -T $SSH_OPTIONS "if [ -f ~/.ssh/authorized_keys ]; then grep \"$SSH_KEY\" ~/.ssh/authorized_keys; fi")
						if [ -z "${SSH_KEYS}" ]; then
							cat "$SSH_FILEPATH/$SSH_FILENAME.pub" | sshpass -p ${DATABASE_VALUES[3]} ssh ${DATABASE_VALUES[0]} -l ${DATABASE_VALUES[2]} -p ${DATABASE_VALUES[1]} -T $SSH_OPTIONS "mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod -R go= ~/.ssh && cat >> ~/.ssh/authorized_keys"
							declare SSH_KEYS=$(sshpass -p ${DATABASE_VALUES[3]} ssh ${DATABASE_VALUES[0]} -l ${DATABASE_VALUES[2]} -p ${DATABASE_VALUES[1]} -T $SSH_OPTIONS "if [ -f ~/.ssh/authorized_keys ]; then grep \"$SSH_KEY\" ~/.ssh/authorized_keys; fi")
							if [ -z "${SSH_KEYS}" ]; then
								SERVERS_LOG "$TEXT error copying SSH public key to \"~/.ssh/authorized_keys\"."
							else
								SERVERS_LOG "$TEXT SSH public key copied successfully to \"~/.ssh/authorized_keys\"."
							fi
						else
							SERVERS_LOG "$TEXT SSH public key already exists in \"~/.ssh/authorized_keys\"."
						fi
						unset SSH_KEYS
#						sshpass -p ${DATABASE_VALUES[3]} ssh ${DATABASE_VALUES[0]} -l ${DATABASE_VALUES[2]} -p ${DATABASE_VALUES[1]} -T $SSH_OPTIONS "echo \"System uptime:\"; uptime; printf \"\\\n\"; echo \"System storage info:\"; df -h; printf \"\\\n\"; echo \"Current user folder content:\"; ls -la"
#						sshpass -p ${DATABASE_VALUES[3]} scp -p ${DATABASE_VALUES[1]} ~/script.sh ${DATABASE_VALUES[2]}@${DATABASE_VALUES[0]}:~/
						SERVERS_UPDATE "${DATABASE_VALUES[0]}" "${DATABASE_VALUES[1]}" "${DATABASE_VALUES[2]}" "${DATABASE_VALUES[3]}" "$SSH_OPTIONS"
						SERVERS_FIREWALL "${DATABASE_VALUES[0]}" "${DATABASE_VALUES[1]}" "${DATABASE_VALUES[2]}" "${DATABASE_VALUES[3]}" "$SSH_OPTIONS"
						SERVERS_ANSIBLE "${DATABASE_VALUES[0]}" "${DATABASE_VALUES[1]}" "${DATABASE_VALUES[2]}" "${DATABASE_VALUES[3]}" "$SSH_OPTIONS"
					else
						TEXT="$TEXT can not connect to SSH server with login \"${DATABASE_VALUES[2]}\" and password \"${DATABASE_VALUES[3]}\""
						if [ -z "${SSH_CONNECTION}" ]; then
							SERVERS_LOG "$TEXT."
						else
							SERVERS_LOG "$TEXT:"
							echo "$SSH_CONNECTION"
						fi
					fi
				else
					TEXT="$TEXT can not connect to SSH server on port \"${DATABASE_VALUES[1]}\""
					if [ -z "${SSH_CONNECTION}" ]; then
						SERVERS_LOG "$TEXT."
					else
						SERVERS_LOG "$TEXT:"
						echo "$SSH_CONNECTION"
					fi
				fi
				unset SSH_CONNECTION
				unset TEXT
				SERVERS_LOG "-----------------------"
#				printf "\n"
			fi
			unset DATABASE_VALUES
			unset DATABASE_STRING
		done
		unset DATABASE_FILE
		unset SSH_KEY
	else
	        SERVERS_LOG "ERROR: SSH private key not loaded. Can not continue."
		sleep 3
	fi
	unset SSH_OPTIONS
	unset RESULT
### Finish actions for work with forced private key SSH auth:
	if [ "${SSH_FORCE_KEY_AUTH}" == true ]; then
		SERVERS_SSH_ADD_STOP
	fi
### Remove variables:
	unset DATABASE_DELIMITER
	unset DATABASE_FILENAME
	unset DATABASE_FILEPATH
	unset SSH_FORCE_KEY_AUTH
	unset SSH_KEY_PASSPHRASE
	unset SSH_FILENAME
	unset SSH_FILEPATH
	printf "\n"
#	sleep 1
}
### -------------------------------------------------------------------------------------------------
### --- Ansible Run ---------------------------------------------------------------------------------
function SERVERS_ANSIBLE_RUN() {
### Get input variables:
	declare SSH_FILEPATH="${1}"
	declare SSH_FILENAME="${2}"
	declare SSH_KEY_PASSPHRASE="${3}"
	declare DATABASE_FILEPATH="${4}"
	declare DATABASE_FILENAME="${5}"
	declare DATABASE_DELIMITER="${6}"
	declare ANSIBLE_FILEPATH="${7}"
	declare ANSIBLE_FILENAME_INVENTORY="${8}"
	declare ANSIBLE_FILENAME_PLAYBOOK="${9}"
	SERVERS_SSH_ADD_START "$SSH_FILEPATH" "$SSH_FILENAME" "$SSH_KEY_PASSPHRASE"
	if [ $? == 0 ]; then
	        SERVERS_LOG "SSH private key passphrase loaded successfully."
	        SERVERS_LOG "Check fingerprint of remote servers in \"~/.ssh/known_hosts\"..."
### Loop through the database file:
		IFS=$'\n' read -rd "" -a DATABASE_FILE <<< $(cat "$DATABASE_FILEPATH/$DATABASE_FILENAME")
		for DATABASE_STRING in "${DATABASE_FILE[@]}"; do
### Removing all spaces (" "), then replacing all "||" to "|#|", then removing "|" from the end of the line, and then removing CR ("\r") from the line:
			DATABASE_STRING=$(echo "$DATABASE_STRING" | sed "s/ //g" | sed "s/${DATABASE_DELIMITER}${DATABASE_DELIMITER}/${DATABASE_DELIMITER}\#${DATABASE_DELIMITER}/g" | sed "s/${DATABASE_DELIMITER}$//" | sed "s/\r$//")
			declare -a DATABASE_VALUES=(${DATABASE_STRING//"$DATABASE_DELIMITER"/ })
### Check if line is not a comment:
			if [ "${DATABASE_VALUES[0]:0:1}" != "#" ]; then
### Connect with SSH to all serves in database file:
					declare SSH_HOST=$(sudo ssh-keygen -F "${DATABASE_VALUES[0]}" 2>/dev/null | grep "= ssh-rsa ") >/dev/null 2>&1
					if [ -z "${SSH_HOST}" ]; then
					        SERVERS_LOG "Server \"${DATABASE_VALUES[0]}\" fingerprint not found in \"~/.ssh/known_hosts\", add it..."
						(sudo ssh-keyscan -H "${DATABASE_VALUES[0]}" >> ~/.ssh/known_hosts) >/dev/null 2>&1
#					else
#					        SERVERS_LOG "Server \"${DATABASE_VALUES[0]}\" fingerprint was found in \"~/.ssh/known_hosts\"."
					fi
				unset DATABASE_VALUES
			fi
			unset DATABASE_STRING
		done
		unset DATABASE_FILE
	        SERVERS_LOG "Starting Ansible..."
#		ansible all -i ~/ansible-hosts.ini -m ping
#		ansible all -i ~/ansible-hosts.ini -m setup
#		ansible SERVER-01 -i ~/ansible-hosts.ini -m setup
#		ansible servers -i ~/ansible-hosts.ini -m shell -a "uptime"
#		ansible all --limit SERVER* -i ~/ansible-hosts.ini -m shell -a "df -h"
#		ansible-playbook -i ~/ansible-hosts.ini -l SERVER-01 ~/ansible-setup.yml --ask-become-pass
#		sudo ansible-playbook -i "$ANSIBLE_FILEPATH/$ANSIBLE_FILENAME_INVENTORY" "$ANSIBLE_FILEPATH/$ANSIBLE_FILENAME_PLAYBOOK" | sed 's/\\n/\n/g'
		sudo ansible-playbook -i "$ANSIBLE_FILEPATH/$ANSIBLE_FILENAME_INVENTORY" "$ANSIBLE_FILEPATH/$ANSIBLE_FILENAME_PLAYBOOK"
	else
	        SERVERS_LOG "ERROR: SSH private key not loaded. Can not continue."
	fi
	unset RESULT

	unset ANSIBLE_FILENAME_PLAYBOOK
	unset ANSIBLE_FILENAME_INVENTORY
	unset ANSIBLE_FILEPATH
	unset DATABASE_DELIMITER
	unset DATABASE_FILENAME
	unset DATABASE_FILEPATH
	unset SSH_KEY_PASSPHRASE
	unset SSH_FILENAME
	unset SSH_FILEPATH
	SERVERS_SSH_ADD_STOP
}
### -------------------------------------------------------------------------------------------------
### --- Main block ----------------------------------------------------------------------------------
function SERVERS_MAIN() {
### Get input variables:
	declare SSH_FILEPATH="${1}"
	declare SSH_FILENAME="${2}"
	declare SSH_KEY_PASSPHRASE="${3}"
	declare SSH_FORCE_KEY_AUTH="${4}"
	declare DATABASE_FILEPATH="${5}"
	declare DATABASE_FILENAME="${6}"
	declare DATABASE_DELIMITER="${7}"
	declare ANSIBLE_FILEPATH="${8}"
	declare ANSIBLE_FILENAME_INVENTORY="${9}"
	declare ANSIBLE_FILENAME_PLAYBOOK="${10}"
	SERVERS_SELECT_ANSWER "Run full tests for updates, ssh server, firewall and ansible?" "Tests are starting..." "Tests were skipped."
	if [ $? == 0 ]; then
		SERVERS_UPDATE
		SERVERS_SSH_SERVER
		SERVERS_FIREWALL
		SERVERS_ANSIBLE
	fi
### Select NODE type:
	if [ -f "$DATABASE_FILEPATH/$DATABASE_FILENAME" ]; then
		SERVERS_LOG "Found database filename: \"$DATABASE_FILEPATH/$DATABASE_FILENAME\"."
### Select answer to start servers modification or not:
		SERVERS_SELECT_ANSWER "This is a MASTER node (primary management, not managed by Ansible)?" "This is a MASTER node. Continue..." "This is a SLAVE node. Nothing to do."
		if [ $? == 0 ]; then
### Starting SSH keys deploy to all servers in database:
			SERVERS_SELECT_ANSWER "Run SSH keys deploy/check?" "SSH keys check is starting..." "SSH keys check was skipped."
			if [ $? == 0 ]; then
				SERVERS_SSH_DEPLOY "$SSH_FILEPATH" "$SSH_FILENAME" "$SSH_KEY_PASSPHRASE" "$SSH_FORCE_KEY_AUTH" "$DATABASE_FILEPATH" "$DATABASE_FILENAME" "$DATABASE_DELIMITER"
			fi
### Select answer to start Ansible or not:
			SERVERS_SELECT_ANSWER "Run Ansible inventory/playbook/script?" "Ansible is starting..." "Ansible was skipped."
			if [ $? == 0 ]; then
				SERVERS_ANSIBLE_RUN "$SSH_FILEPATH" "$SSH_FILENAME" "$SSH_KEY_PASSPHRASE" "$DATABASE_FILEPATH" "$DATABASE_FILENAME" "$DATABASE_DELIMITER" "$ANSIBLE_FILEPATH" "$ANSIBLE_FILENAME_INVENTORY" "$ANSIBLE_FILENAME_PLAYBOOK"
			fi
		fi
	fi
	unset ANSIBLE_FILENAME_PLAYBOOK
	unset ANSIBLE_FILENAME_INVENTORY
	unset ANSIBLE_FILEPATH
	unset DATABASE_DELIMITER
	unset DATABASE_FILENAME
	unset DATABASE_FILEPATH
	unset SSH_FORCE_KEY_AUTH
	unset SSH_KEY_PASSPHRASE
	unset SSH_FILENAME
	unset SSH_FILEPATH
}
### -------------------------------------------------------------------------------------------------
### --- Main start ----------------------------------------------------------------------------------
# if [ $(whoami) != "root" ]; then
#        SERVERS_LOG "Authorizing as root user..."
#	sudo su -
# fi
SERVERS_MAIN "$SSH_FILEPATH" "$SSH_FILENAME" "$SSH_KEY_PASSPHRASE" "$SSH_FORCE_KEY_AUTH" "$DATABASE_FILEPATH" "$DATABASE_FILENAME" "$DATABASE_DELIMITER" "$ANSIBLE_FILEPATH" "$ANSIBLE_FILENAME_INVENTORY" "$ANSIBLE_FILENAME_PLAYBOOK"
### -------------------------------------------------------------------------------------------------
