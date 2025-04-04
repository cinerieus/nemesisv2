#!/bin/sh
# Stop mgmt ports being exposed on VPN interfaces
sudo pacman --noconfirm -Sy ufw
interface=$(ip route get 1.1.1.1 | sed -nr 's/.*dev ([^\ ]+).*/\1/p')
sudo ufw allow in on $interface to any port 22
sudo ufw allow in on $interface to any port 3389
sudo ufw deny 22/tcp
sudo ufw deny 3389/tcp
sudo ufw enable
sudo ufw reload
unset interface
