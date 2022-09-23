#!/bin/bash
### -------------------------------------------------------------------------------------------------
# COPYRIGHT: EQUULEUS [https://github.com/equuleus]
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
### Path to SSH RSA Private and Public keys:
declare FILEPATH="$PWD"
declare SCRIPT_FILENAME="servers.sh"
declare SCRIPT_FILEPATH="../SERVERS"
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
# Set variables:
declare -a EXPECT_QUESTIONS=("\[y/n\]" "\[y/n\]" "\[y/n\]" "\[y/n\]" "Enter passphrase" "\[sudo\]")
declare -a EXPECT_ANSWERS=("n" "y" "n" "y" "CRYPTUS" "password")
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
# Install "expect":
EXPECT=$(apt list --installed 2>/dev/null | grep -w "expect") >/dev/null 2>&1
if [ -z "${EXPECT}" ]; then
	sudo apt-get install expect -y >/dev/null 2>&1
fi
unset EXPECT
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
# Create auto-answer commands:
declare EXPECT_COMMAND=""
declare -i LENGTH="${#EXPECT_QUESTIONS[@]}"
for (( i=0; i<${LENGTH}; i++ )); do
	if [ -z "${EXPECT_COMMAND}" ]; then
		EXPECT_COMMAND="sleep 0.3; expect \"${EXPECT_QUESTIONS[$i]}\" { send \"${EXPECT_ANSWERS[$i]}\r\" }"
	else
		EXPECT_COMMAND="${EXPECT_COMMAND}; sleep 0.3; expect \"${EXPECT_QUESTIONS[$i]}\" { send \"${EXPECT_ANSWERS[$i]}\r\" }"
	fi
done
unset LENGTH
unset EXPECT_ANSWERS
unset EXPECT_QUESTIONS
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
/usr/bin/expect -c '
	set timeout -1;
	spawn bash -c "cd '"${SCRIPT_FILEPATH}"' && ./'"${SCRIPT_FILENAME}"' && cd '"${FILEPATH}"'";
	'"${EXPECT_COMMAND}"';
	interact;
'
unset EXPECT_COMMAND
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
unset SCRIPT_FILEPATH
unset SCRIPT_FILENAME
unset FILEPATH
### -------------------------------------------------------------------------------------------------
