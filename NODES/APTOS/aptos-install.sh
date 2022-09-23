#!/bin/bash
### https://aptos.dev/nodes/ait/connect-to-testnet#using-docker
### https://nodes.guru/aptos/setup-guide/ru
### https://api.nodes.guru/aptos_ait3.sh
clear
echo -e "\e[32mSTARTING...\e[39m"
### Check processor type:
# if ! grep -q -w "avx2" /proc/cpuinfo; then
#	echo -e "\e[31mInstallation is not possible, your server does not support \"AVX2\", change your server and try again.\e[39m"
#	exit
# fi
### Check necessary ports:
declare -a PORTS=("80" "6180" "6181" "6182" "9101")
for PORT in "${PORTS[@]}"; do
	if ss -tulpen | awk '{print $5}' | grep -q ":$PORT$" ; then
		echo -e "\e[31mInstallation is not possible, port \"$PORT\" is already in use.\e[39m"
		exit
	fi
	unset PORT
done
### Declare node name variable:
declare APTOS_NODENAME="APTOS"
# if [ ! $APTOS_NODENAME ]; then read -p "Enter node name: " APTOS_NODENAME fi
### Set DNS fail-safe server:
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
# echo "nameserver 8.8.8.8" | sudo tee /etc/resolvconf/resolv.conf.d/base > /dev/null
### Install and update system packages:
echo -e "\e[32mINSTALLING AND UPDATING SYSTEM PACKAGES...\e[39m"
sudo apt update && sudo apt upgrade -y && sudo apt install curl git sudo unzip wget libssl-dev -y > /dev/null 2>&1
### Check ".bash_profile" file exists:
if [ -f "$HOME/.bash_profile" ]; then
    . $HOME/.bash_profile
fi
echo -e "\e[32mOPENING PORTS \"${PORTS[@]}\"...\e[39m"
### Open ports:
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/ports_opening.sh) "${PORTS[@]}"
unset PORTS
### Set source file for ".bash_profile":
echo "source $HOME/.bashrc" >> $HOME/.bash_profile
### Export "APTOS_NODENAME" to ".bash_profile":
echo "export APTOS_NODENAME=\"${APTOS_NODENAME}\"" >> $HOME/.bash_profile
### Set "WORKSPACE" to ".bash_profile":
echo "export WORKSPACE=\"$HOME/.aptos\"" >> $HOME/.bash_profile
. $HOME/.bash_profile
echo -e "\e[32mINSTALLING DOCKER...\e[39m"
### Install "Docker":
if ! [ -x "$(command -v docker)" ]; then
	curl -fsSL https://get.docker.com -o get-docker.sh
	sudo sh get-docker.sh
	rm -f get-docker.sh
fi
echo -e "\e[32mINSTALLING DOCKER COMPOSE...\e[39m"
### Install "Docker Compose":
if ! [ -x "$(command -v docker-compose)" ] || ! [ -f "/usr/local/bin/docker-compose" ]; then
	sudo curl -SL https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
	sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi
echo -e "\e[32mINSTALLING APTOS...\e[39m"
### Install APTOS:
wget -qO aptos-cli.zip https://github.com/aptos-labs/aptos-core/releases/download/aptos-cli-v0.3.1/aptos-cli-0.3.1-Ubuntu-x86_64.zip
unzip -o aptos-cli.zip
rm -f aptos-cli.zip
chmod +x aptos
sudo mv aptos /usr/local/bin
echo -e "\e[32mAPTOS SETTING...\e[39m"
### Create folder, download config:
mkdir -p $HOME/.aptos
cd $HOME/.aptos
### Download Docker Compose and Validator yaml configurations:
wget -O $HOME/.aptos/docker-compose.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/main/docker/compose/aptos-node/docker-compose.yaml
wget -O $HOME/.aptos/validator.yaml https://raw.githubusercontent.com/aptos-labs/aptos-core/main/docker/compose/aptos-node/validator.yaml
### Generate new keys:
/usr/local/bin/aptos genesis generate-keys --assume-yes --output-dir $HOME/.aptos/keys
declare IP=$(curl ifconfig.me)
# declare IP=$(wget -qO- eth0.me)
### Set validator configuration:
/usr/local/bin/aptos genesis set-validator-configuration --local-repository-dir $HOME/.aptos --username $APTOS_NODENAME --owner-public-identity-file $HOME/.aptos/keys/public-keys.yaml --validator-host $IP:6180 --stake-amount 100000000000000
unset IP
### Generate new startup configuration "layout.yaml" file:
# aptos genesis generate-layout-template --output-file $HOME/.aptos/layout.yaml
### Make new "layout.yaml" file with changes:
echo "---
root_key: "D04470F43AB6AEAA4EB616B72128881EEF77346F2075FFE68E14BA7DEBD8095E"
users: [\"$APTOS_NODENAME\"]
chain_id: 43
allow_new_validators: false
epoch_duration_secs: 7200
is_test: true
min_stake: 100000000000000
min_voting_threshold: 100000000000000
max_stake: 100000000000000000
recurring_lockup_duration_secs: 86400
required_proposer_stake: 100000000000000
rewards_apy_percentage: 10
voting_duration_secs: 43200
voting_power_increase_limit: 20" > layout.yaml
### Download new framework ("framework.mrb") file:
wget https://github.com/aptos-labs/aptos-core/releases/download/aptos-framework-v0.3.0/framework.mrb -P $HOME/.aptos
### Download (generate) new "genesis.blob" & "waypoint.txt" files:
/usr/local/bin/aptos genesis generate-genesis --assume-yes --local-repository-dir $HOME/.aptos --output-dir $HOME/.aptos
### Remove old image/container:
if ! [ -z '$(sudo docker container list 2>/dev/null | grep -w "aptoslabs/validator:testnet")' ]; then
	sudo docker rmi -f "aptoslabs/validator:testnet" >/dev/null 2>&1
# sudo docker container list
fi
### Turn on Docker Compose and compile container:
cd ~/.aptos && sudo docker compose up -d
### Turn off Docker Compose and wait 1 second:
sudo docker-compose down -v
sleep 1
### Run Docker service:
sudo systemctl enable docker.service
### Create auto-start APTOS Docker Compose Service (save parameters to file):
echo "[Unit]
Description=Docker Compose APTOS Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$HOME/.aptos
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
" > $HOME/docker-compose-aptos.service
### Move APTOS Docker Compose Service to system dicrectory:
sudo mv $HOME/docker-compose-aptos.service /etc/systemd/system/
### Restart and reload system service:
sudo systemctl restart systemd-journald
sudo systemctl daemon-reload
echo -e "\e[32mAPTOS START SERVICE AND BUILD DOCKER CONTAINER...\e[39m"
### Enable and start APTOS Docker Compose Service:
sudo systemctl enable docker-compose-aptos
sudo systemctl restart docker-compose-aptos
echo -e "\e[32mDONE!\e[39m"
unset APTOS_NODENAME
