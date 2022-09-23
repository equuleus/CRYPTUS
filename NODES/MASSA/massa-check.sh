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
# !!! /home/user -> /root
declare HOME_PATH="/root"
# declare HOME_PATH="/home/user"
declare IP_ADDRESS=$(wget -qO- eth0.me) >/dev/null 2>&1
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
declare RESULT=$(cd "$HOME_PATH/massa/massa-client" && ./massa-client -p "$PASSWORD" wallet_info)
RESULT=$(echo "$RESULT" | grep -v '^\s*$' | tail -n +2 | head -n -1)
IFS=$'|' read -rd "" -a RESULTS <<< "${RESULT//=====/|}"
RESULT=""
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
declare -a TEXT
declare -a WALLETS
for KEYS in "${RESULTS[@]}"; do
#	echo "$KEYS"
	declare WALLET=$(echo "$KEYS" | grep -w "Address" | awk '{ print $2 }')
	if [ -z "$RESULT" ]; then
		declare BALANCE=$(echo "$KEYS" | grep -w "Final balance" | awk '{ print $3 }')
		declare ROLLS_ACTIVE=$(echo "$KEYS" | grep -w "Active rolls" | awk '{ print $3 }')
		declare ROLLS_FINAL=$(echo "$KEYS" | grep -w "Final rolls" | awk '{ print $3 }')
		declare ROLLS_CANDIDATE=$(echo "$KEYS" | grep -w "Candidate rolls" | awk '{ print $3 }')
		if [ "$ROLLS_ACTIVE" -ne "0" ] || [ "$ROLLS_FINAL" -ne "0" ] || [ "$ROLLS_CANDIDATE" -ne "0" ] || [ "$BALANCE" -gt "0" ]; then
			if [ "$ROLLS_ACTIVE" -eq "1" ] && [ "$ROLLS_FINAL" -eq "1" ] && [ "$ROLLS_CANDIDATE" -eq "1" ]; then
				RESULT="'OK'"
			else
				RESULT="'ERROR'"
			fi
			TEXT+=("IP: '$IP_ADDRESS'")
			TEXT+=("WALLET (ADDRESS): '$WALLET'")
			TEXT+=("BALANCE (FINAL): '$BALANCE'")
			TEXT+=("ROLLS (ACTIVE / FINAL / CANDIDATE): '$ROLLS_ACTIVE' / '$ROLLS_FINAL' / '$ROLLS_CANDIDATE'")
		fi
		unset ROLLS_CANDIDATE
		unset ROLLS_FINAL
		unset ROLLS_ACTIVE
		unset BALANCE
	fi
	WALLETS+=("$WALLET")
	unset WALLET
	unset KEYS
done
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
echo ""
if ! [ -z "$RESULT" ]; then
	echo "RESULT: ${RESULT}"
	for LINE in "${TEXT[@]}"; do
		echo "$LINE"
		unset LINE
	done
else
	echo "RESULT: ERROR (NOT FOUND ACTIVE ROLLS OR TOKENS ON BALANCE)"
	echo "IP: '$IP_ADDRESS'"
	for WALLET in "${WALLETS[@]}"; do
		echo "WALLET (ADDRESS): '$WALLET'"
		unset WALLET
	done
fi
### -------------------------------------------------------------------------------------------------
### -------------------------------------------------------------------------------------------------
unset WALLETS
#echo "$TEXT" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"
### -------------------------------------------------------------------------------------------------
### Remove variables:
unset TEXT
unset RESULTS
unset RESULT
unset IP_ADDRESS
unset HOME_PATH
unset PASSWORD
### -------------------------------------------------------------------------------------------------
