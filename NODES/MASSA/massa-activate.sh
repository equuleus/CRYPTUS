#!/bin/bash
### -------------------------------------------------------------------------------------------------
# COPYRIGHT: EQUULEUS [https://github.com/equuleus]
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
clear
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set main variables:
declare PASSWORD="CRYPTUS"
declare FILEPATH="/root/massa_backup"
declare FILENAME="info.txt"
# !!! /home/user -> /root
declare HOME_PATH="/root"
# declare HOME_PATH="/home/user"
### Creating a full file name from path & name:
declare FILE_NAME="$FILEPATH/$FILENAME"
### Set database path, filename and base delimiter:
declare DATABASE_FILEPATH="$HOME_PATH"
declare DATABASE_FILENAME="massa.txt"
declare DATABASE_DELIMITER="|"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Remove old file if exists:
if [ -f "$FILE_NAME" ]; then
	rm -f "$FILE_NAME" >/dev/null 2>&1
fi
touch "$FILE_NAME" >/dev/null 2>&1
### Get server IP address:
declare IP_ADDRESS=$(wget -qO- eth0.me) >/dev/null 2>&1
echo "IP: $IP_ADDRESS" >> "$FILE_NAME"
printf "\n" >> "$FILE_NAME"
### Set command to execute:
declare RESULT=$(cd "$HOME_PATH/massa/massa-client" && ./massa-client -p "$PASSWORD" wallet_info)
RESULT=$(echo "$RESULT" | sed -n '/WARNING/, $p' | grep -v '^\s*$' | tail -n +2 | head -n -1)
### Replace in "RESULT" value "=====" with "|" and then devide it to elements of an array "RESULTS":
IFS=$'|' read -rd "" -a RESULTS <<< "${RESULT//=====/|}"
if [ -f "$DATABASE_FILEPATH/$DATABASE_FILENAME" ]; then
	IFS=$'\n' read -rd "" -a DATABASE_FILE <<< $(cat "$DATABASE_FILEPATH/$DATABASE_FILENAME")
	for DATABASE_STRING in "${DATABASE_FILE[@]}"; do
### Removing all spaces (" "), then replacing all "||" to "|#|", then removing "|" from the end of the line, and then removing CR ("\r") from the line:
		DATABASE_STRING=$(echo "$DATABASE_STRING" | sed "s/ //g" | sed "s/${DATABASE_DELIMITER}${DATABASE_DELIMITER}/${DATABASE_DELIMITER}\#${DATABASE_DELIMITER}/g" | sed "s/${DATABASE_DELIMITER}$//" | sed "s/\r$//")
		declare -a DATABASE_VALUES=(${DATABASE_STRING//"$DATABASE_DELIMITER"/ })
		if [ "${DATABASE_VALUES[0]:0:1}" != "#" ]; then
			declare DATABASE_SERVER="${DATABASE_VALUES[0]}"
			declare DATABASE_IP="${DATABASE_VALUES[1]}"
			declare DATABASE_WALLET="${DATABASE_VALUES[2]}"
			declare DATABASE_DISCORD="${DATABASE_VALUES[3]}"
			declare DATABASE_ADS="${DATABASE_VALUES[4]}"
			if [ "$DATABASE_IP" == "$IP_ADDRESS" ]; then
				for KEYS in "${RESULTS[@]}"; do
#					echo "$KEYS"
					declare WALLET=$(echo "$KEYS" | grep -w "Address" | awk '{ print $2 }')
					declare BALANCE=$(echo "$KEYS" | grep -w "Final balance" | awk '{ print $3 }')
					declare ROLLS_ACTIVE=$(echo "$KEYS" | grep -w "Active rolls" | awk '{ print $3 }')
					declare ROLLS_FINAL=$(echo "$KEYS" | grep -w "Final rolls" | awk '{ print $3 }')
					declare ROLLS_CANDIDATE=$(echo "$KEYS" | grep -w "Candidate rolls" | awk '{ print $3 }')
					if ! [ -z "$WALLET" ]; then
						if [ "$WALLET" == "$DATABASE_WALLET" ]; then
							echo "WALLET (ADDRESS): $WALLET" >> "$FILE_NAME"
							printf "\n" >> "$FILE_NAME"
							echo "BALANCE (FINAL): $BALANCE" >> "$FILE_NAME"
							printf "\n" >> "$FILE_NAME"
							declare ANSWER=$(cd "$HOME_PATH/massa/massa-client" && ./massa-client -p "$PASSWORD" get_status | grep -w "Error" | awk '{print $1}')
							if ! [ -z "$ANSWER" ]; then
								if [ "$BALANCE" -gt 0 ]; then
									if [ "$ROLLS_FINAL" -eq 0 ]; then
										if [ "$BALANCE" -ge 100 ]; then
											ANSWER=$(cd "$HOME_PATH/massa/massa-client" && ./massa-client -p "$PASSWORD" buy_rolls "$WALLET" 1 0)
											if ! [ -z '$(echo "$ANSWER" | grep -w "Sent operation IDs")' ]; then
												declare ID=$(echo "$ANSWER" | sed -n "3p")
												echo "INFO: command execute \"buy_rolls\" successfull: sent operation ID \"$ID\"." >> "$FILE_NAME"
												unset ID
												printf "\n" >> "$FILE_NAME"
												ANSWER=$(cd "$HOME_PATH/massa/massa-client" && ./massa-client -p "$PASSWORD" node_add_staking_secret_keys)
												if ! [ -z '$(echo "$ANSWER" | grep -w "Keys successfully added")' ]; then
													echo "INFO: command execute \"node_add_staking_secret_keys\" successfull: \"$ANSWER\"." >> "$FILE_NAME"
												else
													echo "ERROR: command execute \"node_add_staking_secret_keys\" unsuccessfull: \"$ANSWER\"." >> "$FILE_NAME"
												fi
											else
												echo "ERROR: command execute \"buy_rolls\" unsuccessfull: \"$ANSWER\"." >> "$FILE_NAME"
											fi
										else
											echo "ERROR: not enough tokens to buy a roll ($BALANCE of 100)." >> "$FILE_NAME"
										fi
										printf "\n" >> "$FILE_NAME"
									fi
								fi
								if [ "$ROLLS_ACTIVE" -eq 0 ] && [ "$ROLLS_FINAL" -gt 0 ] && [ "$ROLLS_CANDIDATE" -gt 0 ]; then
									ANSWER=$(cd "$HOME_PATH/massa/massa-client" && ./massa-client -p "$PASSWORD" node_add_staking_secret_keys)
									if ! [ -z '$(echo "$ANSWER" | grep -w "Keys successfully added")' ]; then
										echo "INFO: command execute \"node_add_staking_secret_keys\" successfull: \"$ANSWER\"." >> "$FILE_NAME"
									else
										echo "ERROR: command execute \"node_add_staking_secret_keys\" unsuccessfull: \"$ANSWER\"." >> "$FILE_NAME"
									fi
									printf "\n" >> "$FILE_NAME"
								fi
								ANSWER=$(cd "$HOME_PATH/massa/massa-client" && ./massa-client -p "$PASSWORD" node_testnet_rewards_program_ownership_proof "$WALLET" "$DATABASE_DISCORD")
								if ! [ -z '$(echo "$ANSWER" | grep -w "Enter the following in discord")' ]; then
#									echo "INFO: command execute \"node_testnet_rewards_program_ownership_proof\" successfull: \"$ANSWER\"." >> "$FILE_NAME"
									ANSWER=$(echo "$ANSWER" | sed -n "2p")
									echo "DISCORD: $ANSWER" >> "$FILE_NAME"
								else
									echo "ERROR: command execute \"node_testnet_rewards_program_ownership_proof\" unsuccessfull: \"$ANSWER\"." >> "$FILE_NAME"
								fi
								printf "\n" >> "$FILE_NAME"
							else
								echo "ERROR: command execute \"get_status\" unsuccessfull: \"$ANSWER\"." >> "$FILE_NAME"
								printf "\n" >> "$FILE_NAME"
							fi
							unset ANSWER
						fi
					else
						echo "ERROR: wallet address not found, response was: \"$KEYS\"" >> "$FILE_NAME"
						printf "\n" >> "$FILE_NAME"
						sudo systemctl restart massad
					fi
					unset ROLLS_CANDIDATE
					unset ROLLS_FINAL
					unset ROLLS_ACTIVE
					unset BALANCE
					unset WALLET
					unset KEYS
				done
			fi
			unset DATABASE_ADS
			unset DATABASE_DISCORD
			unset DATABASE_WALLET
			unset DATABASE_IP
			unset DATABASE_SERVER
		fi
		unset DATABASE_VALUES
		unset DATABASE_STRING
	done
	unset DATABASE_FILE
fi
### Echo result:
cat "$FILE_NAME"
### Remove variables:
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
unset RESULTS
unset RESULT
unset IP_ADDRESS
unset DATABASE_DELIMITER
unset DATABASE_FILENAME
unset DATABASE_FILEPATH
unset HOME_PATH
unset FILENAME
unset FILEPATH
unset PASSWORD
### -------------------------------------------------------------------------------------------------
