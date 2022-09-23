#!/bin/bash

### Based on:
### https://github.com/SecorD0/Massa/blob/main/multi_tool.sh

declare PASSWORD=CRYPTUS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
# echo "nameserver 8.8.8.8" | sudo tee /etc/resolvconf/resolv.conf.d/base > /dev/null
sudo apt install wget -y &>/dev/null
cd
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/colors.sh) --
printf_n() { printf "$1\n" "${@:2}"; }
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
install() {
	declare massa_password="$1"
	if ! [ -d $HOME/massa/ ]; then
		if [ ! -n "$massa_password" ]; then
			printf_n "${C_R}There is no massa_password variable with the password!${RES}\n"
			return 1 2>/dev/null; exit 1
		fi
		sudo apt update
		sudo apt upgrade -y
		sudo apt install jq curl pkg-config git build-essential libssl-dev -y
		printf_n "${C_LGn}Node installation...${RES}"
		local massa_version=`wget -qO- https://api.github.com/repos/massalabs/massa/releases/latest | jq -r ".tag_name"`
		wget -qO $HOME/massa.tar.gz "https://github.com/massalabs/massa/releases/download/${massa_version}/massa_${massa_version}_release_linux.tar.gz"
		if [ `wc -c < "$HOME/massa.tar.gz"` -ge 1000 ]; then
			tar -xvf $HOME/massa.tar.gz
			rm -rf $HOME/massa.tar.gz
			chmod +x $HOME/massa/massa-node/massa-node $HOME/massa/massa-client/massa-client
			. <(wget -qO- https://raw.githubusercontent.com/SecorD0/Massa/main/insert_variables.sh)
			replace_bootstraps
			sudo tee <<EOF >/dev/null /etc/systemd/system/massad.service
[Unit]
Description=Massa Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/massa/massa-node
ExecStart=$HOME/massa/massa-node/massa-node -p "$massa_password"
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
			sudo systemctl enable massad
			sudo systemctl daemon-reload
			sudo systemctl stop massad
			. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/ports_opening.sh) 31244 31245
			sudo tee <<EOF >/dev/null $HOME/massa/massa-node/config/config.toml
[network]
routable_ip = "`wget -qO- eth0.me`"
EOF
			sudo systemctl restart massad
			cd $HOME/massa/massa-client/
			if [ ! -d $HOME/massa_backup ]; then
				./massa-client -p "$massa_password" wallet_generate_secret_key &>/dev/null
				mkdir -p $HOME/massa_backup
				sudo cp $HOME/massa/massa-client/wallet.dat $HOME/massa_backup/wallet.dat
				while true; do
					if [ -f $HOME/massa/massa-node/config/node_privkey.key ]; then
						sudo cp $HOME/massa/massa-node/config/node_privkey.key $HOME/massa_backup/node_privkey.key
						break
					else
						sleep 5
					fi
				done
				
			else
				sudo cp $HOME/massa_backup/node_privkey.key $HOME/massa/massa-node/config/node_privkey.key
				sudo systemctl restart massad
				sudo cp $HOME/massa_backup/wallet.dat $HOME/massa/massa-client/wallet.dat	
			fi
			printf_n "${C_LGn}Done!${RES}"
			cd
			. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/logo.sh)
			printf_n "
The node was ${C_LGn}started${RES}.

Remember to save files in this directory: ${C_LR}$HOME/massa_backup/${RES}
And password for decryption: ${C_LR}${massa_password}${RES}

\tv ${C_LGn}Useful commands${RES} v

To run a client: ${C_LGn}massa_client${RES}
To view the node status: ${C_LGn}sudo systemctl status massad${RES}
To view the node log: ${C_LGn}massa_log${RES}
To restart the node: ${C_LGn}sudo systemctl restart massad${RES}

CLI client commands (use ${C_LGn}massa_cli_client -h${RES} to view the help page):
${C_LGn}`compgen -a | grep massa_ | sed "/massa_log/d"`${RES}
"
		else
			rm -rf $HOME/massa.tar.gz
			printf_n "${C_LR}Archive with binary downloaded unsuccessfully!${RES}\n"
		fi
	fi
}

if [ ! -n "$PASSWORD" ]; then
	printf_n "\n${C_LGn}Come up with a password to encrypt the keys and enter it.${RES}"
	. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n PASSWORD
fi
install "$PASSWORD"
