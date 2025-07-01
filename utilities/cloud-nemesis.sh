#!/bin/bash
username=$USERNAME
password=$PASSWORD
ssh_key=$SSHKEYURL

#### Time Zone ####
printf "\n\nSetting timezone...\n"
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd.service

# Configure localization
printf "\nConfiguring locales...\n"
echo C.UTF-8 UTF-8 > /etc/locale.gen
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo en_GB.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
echo LANG=en_GB.UTF-8 > /etc/locale.conf
export LANG=en_GB.UTF-8
echo "
KEYMAP=uk
FONT=Goha-16" > /etc/vconsole.conf

# Configure pacman
printf "\n\nConfiguring Pacman... \n"
curl https://blackarch.org/strap.sh | sh
echo "Server = https://blackarch.org/blackarch/blackarch/os/x86_64" > /etc/pacman.d/blackarch-mirrorlist
pacman --noconfirm -Syu
pacman --noconfirm -Sy base-devel yay systemd-resolvconf openssh git neovim tmux wget p7zip neofetch noto-fonts ttf-noto-nerd fish ldns
# networkmanager less

# Configure users
printf "\n\nConfiguring users...\n"
echo "%wheel    ALL=(ALL) ALL" >> /etc/sudoers
useradd -m -G users,wheel $username
echo -e "$password\n$password" | passwd $username
sudo -Hu $username mkdir /home/$username/.ssh
sudo -Hu $username chmod 750 /home/$username/.ssh
mkdir /opt/workspace
chgrp users /opt/workspace
chmod 775 /opt/workspace
chmod g+s /opt/workspace
setfacl -Rdm g:users:rwx /opt/workspace

# Configure SSH
printf "\n\nConfiguring SSH... \n"
echo "
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
PasswordAuthentication no
MaxAuthTries 10" >> /etc/ssh/sshd_config
systemctl enable sshd.service
if [ -n "$ssh_key" ]; then
    sudo -Hu $username echo $ssh_key > /home/$username/.ssh/authorized_keys
    chmod 600 /home/$username/.ssh/authorized_keys
    chown $username:$username /home/$username/.ssh/authorized_keys
fi

# Customization
printf "\n\nCustomizing... \n"
# Neovim
sudo -u $username curl https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim -o /home/$username/.local/share/nvim/site/autoload/plug.vim --create-dirs
sudo -u $username curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/init.vim -o /home/$username/.config/nvim/init.vim --create-dirs
sudo -u $username nvim +:PlugInstall +:qa
mkdir -p /root/.local/share/nvim/site/autoload && cp /home/$username/.local/share/nvim/site/autoload/plug.vim /root/.local/share/nvim/site/autoload/plug.vim
mkdir -p /root/.config/nvim && cp /home/$username/.config/nvim/init.vim /root/.config/nvim/init.vim
nvim +:PlugInstall +:qa
# Tmux
sudo -u $username git clone https://github.com/tmux-plugins/tpm /home/$username/.tmux/plugins/tpm
sudo -u $username curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/.tmux.conf -o /home/$username/.tmux.conf
sudo -u $username /home/$username/.tmux/plugins/tpm/scripts/install_plugins.sh
git clone https://github.com/tmux-plugins/tpm /root/.tmux/plugins/tpm
curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/.tmux.conf -o /root/.tmux.conf
/root/.tmux/plugins/tpm/scripts/install_plugins.sh
# Fontconfig
curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/local.conf -o /etc/fonts/local.conf --create-dirs
chmod 755 /etc/fonts
sudo -Hu $username curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/.Xresources -o /home/$username/.Xresources && cp /home/$username/.Xresources /root/.Xresources
sudo -Hu $username xrdb -merge /home/$username/.Xresources && xrdb -merge /home/$username/.Xresources
# Fish
sudo -Hu $username curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install > /home/$username/install.fish
sudo -Hu $username fish /home/$username/install.fish --noninteractive && \
mv /home/$username/install.fish /root
sudo -Hu $username git clone https://github.com/cinerieus/theme-sushi.git /home/$username/.local/share/omf/themes/sushi
sudo -Hu $username curl https://raw.githubusercontent.com/cinerieus/nemesis/master/config.fish -o /home/$username/.config/fish/config.fish
sudo -Hu $username fish -c "omf theme sushi"
fish /root/install.fish --noninteractive
rm /root/install.fish
cp -r /home/$username/.local/share/omf/themes/sushi /root/.local/share/omf/themes/
cp -r /home/$username/.config/fish/config.fish /root/.config/fish/config.fish
fish -c "omf theme sushi"
usermod -s /bin/fish $username
usermod -s /bin/fish root


## build specific setup ##
pacman --noconfirm -S open-vm-tools gtkmm3
mkdir -p /etc/xdg/autostart
cp /etc/vmware-tools/vmware-user.desktop /etc/xdg/autostart/vmware-user.desktop
systemctl enable vmtoolsd
systemctl enable vmware-vmblock-fuse

## attac ##
yay --noconfirm -Sy \
socat \
go \
proxychains-ng \
nmap \
masscan \
impacket \
metasploit \
sqlmap \
john \
medusa \
ffuf \
seclists \
ldapdomaindump \
binwalk \
evil-winrm \
responder \
certipy \
httpx \
dnsx \
nuclei \
subfinder \
strace

mkdir -p /opt/workspace/wordlists /opt/workspace/linux /opt/workspace/windows /opt/workspace/peassng /opt/workspace/chisel /opt/workspace/c2/sliver
wget http://downloads.skullsecurity.org/passwords/rockyou.txt.bz2 -O /opt/workspace/wordlists/rockyou.bz2
wget https://github.com/interference-security/kali-windows-binaries/archive/refs/heads/master.zip -O /opt/workspace/windows/binaries.zip
wget https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/archive/refs/heads/master.zip -O /opt/workspace/windows/ghostpack_binaries.zip
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/linpeas.sh -O /opt/workspace/peassng/linpeas.sh
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/winPEAS.bat -O /opt/workspace/peassng/winPEAS.bat
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/winPEASx64.exe -O /opt/workspace/peassng/winPEASx64.exe
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/winPEASx86.exe -O /opt/workspace/peassng/winPEASx86.exe
7z a /opt/workspace/peassng/peassng.7z /opt/workspace/peassng/* && rm -f /opt/workspace/peassng/lin* && rm -f /opt/workspace/peassng/win*
wget https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_linux_amd64.gz -O /opt/workspace/chisel/chisel_1.9.1_linux_amd64.gz
wget https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_windows_amd64.gz -O /opt/workspace/chisel/chisel_1.9.1_windows_amd64.gz
wget https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_windows_386.gz -O /opt/workspace/chisel/chisel_1.9.1_windows_386.gz
wget https://github.com/BishopFox/sliver/releases/download/v1.5.43/sliver-server_linux -O /opt/workspace/c2/sliver/sliver-server
wget https://github.com/BishopFox/sliver/releases/download/v1.5.43/sliver-client_linux -O /opt/workspace/c2/sliver/sliver-client
7z a /opt/workspace/c2/sliver/sliver.7z /opt/workspace/c2/sliver/* && rm -f /opt/workspace/c2/sliver/sliver-*
