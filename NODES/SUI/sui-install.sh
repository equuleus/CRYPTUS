#!/bin/bash
### -------------------------------------------------------------------------------------------------
### Based on:
### https://github.com/SecorD0/utils/
### -------------------------------------------------------------------------------------------------
clear
### --- PERMISSIONS ---------------------------------------------------------------------------------
# sudo -i
### -------------------------------------------------------------------------------------------------
### --- REMOVE --------------------------------------------------------------------------------------
### ������� ����������:
# . <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n sui_log -da
# . <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n sui -da
### ������� Docker ��������� ����:
# sudo docker rm -f "sui_node"
### ������� Docker ����� ���������� ���� (�� �����, ���� �������� ���� ��� �������):
# sudo docker rmi -f "secord/sui"
### ������� ����� ���� (!��������� ��� ������� ��������� �����!):
# rm -rf "$HOME/.sui"
### -------------------------------------------------------------------------------------------------
### --- INSTALL -------------------------------------------------------------------------------------
### �������� ������ � �������:
sudo apt update && sudo apt upgrade -y
### ���������� ����������� ������:
sudo apt install wget jq bc build-essential -y
### ���������� Docker:
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/installers/docker.sh)
### ������� ����� ��� ����:
mkdir -p "$HOME/.sui"
### ������� ���� ��������:
wget -qO $HOME/.sui/genesis.blob https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob
### ������� ������ ����:
wget -qO $HOME/.sui/fullnode.yaml https://github.com/MystenLabs/sui/raw/main/crates/sui-config/data/fullnode-template.yaml
### ��������������� ������:
sed -i -e "s%db-path:.*%db-path: \"$HOME/.sui/db\"%; s%metrics-address:.*%metrics-address: \"0.0.0.0:9184\"%; s%json-rpc-address:.*%json-rpc-address: \"0.0.0.0:9000\"%; s%genesis-file-location:.*%genesis-file-location: \"$HOME/.sui/genesis.blob\"%; " $HOME/.sui/fullnode.yaml
### ������� ������������ �����:
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/ports_opening.sh) 9000 9184
### ��������� ��������� � �����:
sudo docker run -dit --name "sui_node" --restart always -u 0:0 --network host -v "$HOME/.sui:/root/.sui" "secord/sui" --config-path "$HOME/.sui/fullnode.yaml"
### �������� ������� �������� ����� ���������� (�������� ���� ����):
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n sui_log -v "docker logs sui_node -fn100" -a
### �������� ������� �������� ����� ���������� (���������� ������� ��� ���������� �������� �����������):
. <(wget -qO- https://raw.githubusercontent.com/SecorD0/utils/main/miscellaneous/insert_variable.sh) -n sui -v "docker exec -it sui_node ./sui" -a
### -------------------------------------------------------------------------------------------------
### --- UPDATE / RESTART ----------------------------------------------------------------------------
### ���������� ��������� � �����:
# sudo docker stop "sui_node"
### ������� ������ ���� ������:
# rm -rf $HOME/.sui/db
### ������� ����� ���� ��������:
# wget -qO $HOME/.sui/genesis.blob https://github.com/MystenLabs/sui-genesis/raw/main/devnet/genesis.blob
### ������������� ��������� � �����:
# sudo docker start "sui_node"
### ��������� ������
# sui -V
### ����������� ��� ��������:
# active=`grep -oPm1 "(?<=active_address: \")([^%]+)(?=\"$)" $HOME/.sui/sui_config/client.yaml | sed "s%0x%%"`
# new=`docker container exec sui_node ./sui keytool list | awk 'NR==3 {print $1}' | tr -d '[:space:]' | sed "s%0x%%"`
# sed -i -e "s%$active%$new%; " $HOME/.sui/sui_config/client.yaml
### -------------------------------------------------------------------------------------------------
### --- CHECK ---------------------------------------------------------------------------------------
### ���������, ������� �� ������� ����������:
# wget -qO- -t 1 -T 5 --header 'Content-Type: application/json' --post-data '{ "jsonrpc":"2.0", "id":1, "method":"sui_getRecentTransactions", "params":[5] }' "http://127.0.0.1:9000/" | jq
### ���������� ��� ����:
# sui_log
# sudo journalctl -fn 100 -u suid
# sudo docker logs "sui_node" -fn100
### ���������� ��������� ��������:
# sui keytool list
### ���������� ������� ��������� ��������:
# sui client objects
### -------------------------------------------------------------------------------------------------
