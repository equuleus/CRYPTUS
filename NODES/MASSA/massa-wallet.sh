#!/bin/bash
### -------------------------------------------------------------------------------------------------
# COPYRIGHT: EQUULEUS [https://github.com/equuleus]
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
clear
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### "UTF-8" ENCODING ONLY
#use utf8;
declare PASSWORD="CRYPTUS"
declare FILEPATH="/root/massa_backup"
declare FILENAME="info.txt"
### !!! /home/user -> /root
declare HOME_PATH="/root"
# declare HOME_PATH="/home/user"
declare EXPECT_INPUT="›"
### Creating a full file name from path & name:
declare FILE_NAME="$FILEPATH/$FILENAME"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Install "expect":
sudo apt-get install expect -y >/dev/null 2>&1
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Remove old file if exists:
if [ -f "$FILE_NAME" ]; then
	rm -f "$FILE_NAME" >/dev/null 2>&1
fi
touch "$FILE_NAME" >/dev/null 2>&1
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Get server IP address:
declare IP=$(wget -qO- eth0.me) >/dev/null 2>&1
echo "SERVER IP: $IP" >> "$FILE_NAME"
unset IP
printf "\n" >> "$FILE_NAME"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set curent path:
cd "$HOME_PATH/massa/massa-client"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set command to execute:
declare EXPECT_COMMAND="wallet_generate_secret_key"
### Execute real commands with "expect":
EXPECT_OUTPUT=$(/usr/bin/expect -c '
	set timeout 3
	spawn '"$HOME_PATH"'/massa/massa-client/massa-client -p CRYPTUS
	expect "'"$EXPECT_INPUT"'" {
		send "'"$EXPECT_COMMAND"'\r"
	}
	expect "'"$EXPECT_INPUT"'" {
		send "exit\r"
	}
')
unset EXPECT_COMMAND
echo "ANSWER TO COMMAND: \"wallet_generate_secret_key\"" >> "$FILE_NAME"
echo "$EXPECT_OUTPUT" | sed -n '/address and added it to the wallet/, $p' | head -n -2 >> "$FILE_NAME"
unset EXPECT_OUTPUT
printf "\n" >> "$FILE_NAME"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Set command to execute:
declare EXPECT_COMMAND="wallet_info"
### Execute real commands with "expect":
EXPECT_OUTPUT=$(/usr/bin/expect -c '
	spawn '"$HOME_PATH"'/massa/massa-client/massa-client -p CRYPTUS
	expect "'"$EXPECT_INPUT"'" {
		send "'"$EXPECT_COMMAND"'\r"
	}
	expect "'"$EXPECT_INPUT"'" {
		send "exit\r"
	}
')
unset EXPECT_COMMAND
echo "ANSWER TO COMMAND: \"wallet_info\"" >> "$FILE_NAME"
echo "$EXPECT_OUTPUT" | sed -n '/WARNING/, $p' | tail -n +2 | head -n -4 >> "$FILE_NAME"
unset EXPECT_OUTPUT
printf "\n" >> "$FILE_NAME"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Execute virtual commands:
declare -a COMMANDS=("node_info" "wallet_info")
declare -a ARGUMENTS=(" 2>/dev/null" "")
declare -i LENGTH=${#COMMANDS[@]}
for (( i=0; i<${LENGTH}; i++ )); do
	declare -i j=$i+1
	echo "ANSWER TO COMMAND # $j: \"${COMMANDS[$i]}\"" >> "$FILE_NAME"
	echo "$PASSWORD" | . <(wget -qO- https://raw.githubusercontent.com/SecorD0/Massa/main/cli_client.sh) -l RU -a ${COMMANDS[$i]}${ARGUMENTS[$i]} | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" >> "$FILE_NAME"
	printf "\n" >> "$FILE_NAME"
	unset j
done
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Echo result:
cat "$FILE_NAME"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Remove variables:
unset i
unset LENGTH
unset ARGUMENTS
unset COMMANDS
unset FILE_NAME
unset EXPECT_INPUT
unset HOME_PATH
unset FILENAME
unset FILEPATH
unset PASSWORD
### -------------------------------------------------------------------------------------------------
