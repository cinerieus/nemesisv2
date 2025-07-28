#!/bin/bash
read -p "Run Arch-Nemesis install script? [Y/N]" continue
if echo "$continue" | grep -iqFv y; then
        exit 0
fi

# Init variables
hostname="DESKTOP-IJ0CNHN"
username="user"
password="Ch4ngeM3!"
luks_password="1234567890"
ssh_key=""
wifi_ssid=""
wifi_pass=""
vm=true
rdppass="rdp"

# Set keyboard layout
loadkeys uk

# Connect to internet if WiFi
if [ -n "$wifi_ssid" ]; then
    nic=$(ip link | grep "wl"* | grep -o -P "(?= ).*(?=:)" | sed -e "s/^[[:space:]]*//" | cut -d$'\n' -f 1)
    iwctl --passphrase "$wifi_pass" station "$nic" connect "$wifi_ssid"
fi

# Set time and NTP
timedatectl set-timezone UTC
timedatectl set-ntp true

# Disk formatting
printf "\n\nFormatting disk(s)...\n"
umount -f -l /mnt 2>/dev/null
swapoff /dev/mapper/lvgroup-swap 2>/dev/null
vgchange -a n lvgroup 2>/dev/null
cryptsetup close cryptlvm 2>/dev/null
disk=$(sudo fdisk -l | grep "dev" | grep -o -P "(?=/).*(?=:)" | cut -d$'\n' -f1)
echo "label: gpt" | sfdisk --no-reread --force $disk
sfdisk --no-reread --force $disk << EOF
,260M,U,*
;
EOF
if [ "$vm" = true ]; then
    diskpart1=${disk}1
    diskpart2=${disk}2
else
        
    diskpart1=$(sudo fdisk -l | grep "dev" | sed -n "2p" | cut -d " " -f 1)
    diskpart2=$(sudo fdisk -l | grep "dev" | sed -n "3p" | cut -d " " -f 1)
fi

# Disk encryption
printf "\n\nEncrypting disk...\n"
echo $luks_password | cryptsetup -q luksFormat "${diskpart2}"
echo $luks_password | cryptsetup open "${diskpart2}" cryptlvm -
printf "\n\nCreating LVM...\n"
pvcreate -ffy /dev/mapper/cryptlvm
vgcreate lvgroup /dev/mapper/cryptlvm

# Partition /root /swap
printf "\n\nConfiguring /root /swap...\n"
lvcreate -y -L 4G lvgroup -n swap
lvcreate -y -l 100%FREE lvgroup -n root
mkfs.ext4 -FF /dev/lvgroup/root
mkswap /dev/lvgroup/swap
mount /dev/lvgroup/root /mnt
swapon /dev/lvgroup/swap

# Partition /boot
printf "\n\nConfiguring /boot...\n"
mkfs.fat -I -F 32 "${diskpart1}"
mkdir /mnt/boot
mount "${diskpart1}" /mnt/boot

# Init installation
printf "\n\nPacstrap installation...\n"
pacman --noconfirm -Sy archlinux-keyring
pacstrap /mnt base linux linux-firmware lvm2 grub efibootmgr
genfstab -U /mnt >> /mnt/etc/fstab

# Create stage 2 script
printf "\n\nCreating stage 2 script..."
echo "
#!/bin/bash
hostname=\"$hostname\"
username=\"$username\"
password=\"$password\"
luks_password=\"$luks_password\"
ssh_key=\"$ssh_key\"
wifi_ssid=\"$wifi_ssid\"
wifi_pass=\"$wifi_pass\"
vm=\"$vm\"
disk=\"$disk\"
diskpart2=\"$diskpart2\"
rdppass=\"$rdppass\"
" > /mnt/nemesis.sh

echo '
# Configure pacman
printf "\n\nConfiguring Pacman... \n"
echo "
[multilib]
Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
curl https://blackarch.org/strap.sh | sh
echo "Server = https://blackarch.org/blackarch/blackarch/os/x86_64" > /etc/pacman.d/blackarch-mirrorlist
pacman --noconfirm -Syu
pacman --noconfirm -Sy sudo base-devel yay networkmanager systemd-resolvconf openssh git neovim tmux wget p7zip neofetch noto-fonts ttf-noto-nerd fish less ldns

# Set timezone to UTC
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

# Configure network (consider systemd-networkd)
printf "\n\nConfiguring network...\n"
echo $hostname > /etc/hostname
rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Kill telemetry
echo "
[connectivity]
enabled=false" > /usr/lib/NetworkManager/conf.d/20-connectivity.conf

echo "
MulticastDNS=no
LLMNR=no" >> /etc/systemd/resolved.conf

systemctl enable systemd-resolved.service
systemctl enable NetworkManager.service

# Configure initramfs
printf "n\nConfiguring up initramfs...\n"
echo "HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)" > /etc/mkinitcpio.conf
mkinitcpio -P

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

# Configure bootloader
printf "\n\nConfiguring bootloader...\n"
echo GRUB_DISTRIBUTOR=\"Arch Nemesis\" > /etc/default/grub
grub-install --removable --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --sbat=/usr/share/grub/sbat.csv --modules="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios test true video xfs zfs zfscrypt zfsinfo play cpuid tpm luks lvm"
sudo -u $username /bin/sh -c "echo $password | yay --sudoflags \"-S\" --noconfirm -Sy shim-signed sbsigntools"
mv /boot/EFI/BOOT/BOOTx64.EFI /boot/EFI/BOOT/grubx64.efi
cp /usr/share/shim-signed/shimx64.efi /boot/EFI/BOOT/BOOTx64.EFI
cp /usr/share/shim-signed/mmx64.efi /boot/EFI/BOOT/
mkdir /opt/workspace/sb
openssl req -newkey rsa:4096 -nodes -keyout /opt/workspace/sb/MOK.key -new -x509 -sha256 -days 3650 -subj "/CN=MOK/" -out /opt/workspace/sb/MOK.crt
openssl x509 -outform DER -in /opt/workspace/sb/MOK.crt -out /opt/workspace/sb/MOK.cer
sbsign --key /opt/workspace/sb/MOK.key --cert /opt/workspace/sb/MOK.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux
sbsign --key /opt/workspace/sb/MOK.key --cert /opt/workspace/sb/MOK.crt --output /boot/EFI/BOOT/grubx64.efi /boot/EFI/BOOT/grubx64.efi
mkdir -p /etc/pacman.d/hooks
curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/999-sign_kernel_for_secureboot.hook -o /etc/pacman.d/hooks/999-sign_kernel_for_secureboot.hook
cp /opt/workspace/sb/MOK.cer /boot
chown root:root /opt/workspace/sb
chmod -R 600 /opt/workspace/sb
echo "- Remove /boot/EFI/BOOT/mmx64.efi & /boot/MOK.cer" >> /home/$username/readme.txt
cryptdevice=$(blkid ${diskpart2} -s UUID -o value)
echo GRUB_CMDLINE_LINUX="cryptdevice=UUID=$cryptdevice:cryptlvm" >> /etc/default/grub
curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/theme-grub-catppuccin.zip -o /boot/grub/themes/theme-grub-catppuccin.zip
7z x /boot/grub/themes/theme-grub-catppuccin.zip -o/boot/grub/themes && rm /boot/grub/themes/theme-grub-catppuccin.zip
echo GRUB_THEME=/boot/grub/themes/catppuccin-macchiato-grub-theme/theme.txt >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

## CUSTOMIZATION
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

## DESKTOP ENVIRONMENT
# Install Gnome
pacman --noconfirm -Sy gnome vulkan-intel
systemctl enable gdm.service

# Gnome Shell Extensions
sudo -Hu $username /bin/sh -c "echo $password | yay --sudoflags \"-S\" --noconfirm -Sy gnome-shell-extension-blur-my-shell gnome-shell-extension-tilingshell gnome-shell-extension-no-overview gnome-shell-extension-rounded-window-corners-reborn-git catppuccin-cursors-mocha papirus-icon-theme papirus-folders-catppuccin-git wofi adw-gtk-theme gradience kitty thunar firefox libreoffice glib2-devel pipewire-libcamera"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.shell enabled-extensions "[\"blur-my-shell@aunetx\", \"no-overview@fthx\", \"rounded-window-corners@fxgn\", \"system-monitor@gnome-shell-extensions.gcampax.github.com\", \"tilingshell@ferrarodomenico.com\", \"user-theme@gnome-shell-extensions.gcampax.github.com\"]"
#sudo -Hu $username gnome-extensions enable blur-my-shell@aunetx
#sudo -Hu $username gnome-extensions enable tilingshell@ferrarodomenico.com
#sudo -Hu $username gnome-extensions enable no-overview@fthx
#sudo -Hu $username gnome-extensions enable system-monitor@gnome-shell-extensions.gcampax.github.com
#sudo -Hu $username gnome-extensions enable rounded-window-corners@fxgn
#sudo -Hu $username gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com

# Gnome Shell Theming
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface font-antialiasing "rgba"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.mutter experimental-features "[\"scale-monitor-framebuffer\", \"xwayland-native-scaling\"]"
sudo -Hu $username mkdir -p /home/$username/.config/presets/official
sudo -Hu $username gradience-cli download -n "Catppuccin Macchiato"
sudo -Hu $username gradience-cli apply -n "Catppuccin Macchiato" --gtk both
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface accent-color "slate"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
sudo -Hu $username curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/theme-gnomeshell-catppuccin.zip -o /home/$username/.themes/theme-gnomeshell-catppuccin.zip --create-dirs
sudo -Hu $username 7z x /home/$username/.themes/theme-gnomeshell-catppuccin.zip -o/home/$username/.themes
sudo -Hu $username rm /home/$username/.themes/theme-gnomeshell-catppuccin.zip
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.shell.extensions.user-theme name "Catppuccin-Macchiato-Custom"

# Cursor theming
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-macchiato-lavender-cursors"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.wm.preferences focus-mode "sloppy"

# Icon theming
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
papirus-folders -t Papirus-Dark -C cat-macchiato-lavender

# Wofi theming
sudo -Hu $username curl https://raw.githubusercontent.com/quantumfate/wofi/refs/heads/main/src/macchiato/style.css -o /home/$username/.config/wofi/style.css --create-dirs

# Kitty
sudo -Hu $username curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/kitty.conf -o /home/$username/.config/kitty/kitty.conf --create-dirs

# Keyboard
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.input-sources sources "[(\"xkb\", \"gb\")]"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[\"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/\", \"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/\", \"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/\", \"/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/\"]"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name "Terminal"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "kitty"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding "<Super>t"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name "File Manager"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command "thunar"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding "<Super>f"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name "Launcher"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command "wofi --show run"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding "<Super>r"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ name "Browser"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ command "firefox"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ binding "<Super>b"

# Wallpaper
curl https://w.wallhaven.cc/full/rr/wallhaven-rr9kyw.png -o /opt/workspace/backgrounds/background.png --create-dirs # Set wallpaper here!
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.background picture-uri "file:///opt/workspace/backgrounds/background.png"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.background picture-uri-dark "file:///opt/workspace/backgrounds/background.png"
sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.background picture-options "zoom"

# GDM
sudo -Hu gdm dbus-launch --exit-with-session gsettings set org.gnome.login-screen logo ""
sudo -Hu gdm dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-macchiato-lavender-cursors"
sudo -Hu gdm dbus-launch --exit-with-session gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
sudo -Hu $username curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/utilities/extractgst.sh -o /home/$username/extractgst.sh
chmod +x /home/$username/extractgst.sh
sudo -Hu $username /home/$username/extractgst.sh
sudo -Hu $username magick /opt/workspace/backgrounds/background.png -blur 0x15 /home/$username/shell-theme/theme/background.png
sudo -Hu $username curl https://raw.githubusercontent.com/cinerieus/nemesisv2/refs/heads/main/config/gnome-shell-theme.gresource.xml -o /home/$username/shell-theme/theme/gnome-shell-theme.gresource.xml
sudo -Hu $username sed -i "/lockDialogGroup/,+2d" /home/$username/shell-theme/theme/gnome-shell-light.css
sudo -Hu $username sed -i "/lockDialogGroup/,+2d" /home/$username/shell-theme/theme/gnome-shell-dark.css
echo "
#lockDialogGroup {
  background: url(\"background.png\");
  background-size: auto;
  background-repeat: no-repeat;
}" >> /home/$username/shell-theme/theme/gnome-shell-light.css
echo "
#lockDialogGroup {
  background: url(\"background.png\");
  background-size: auto;
  background-repeat: no-repeat;
}" >> /home/$username/shell-theme/theme/gnome-shell-dark.css
cp /usr/share/gnome-shell/gnome-shell-theme.gresource /usr/share/gnome-shell/gnome-shell-theme-original.gresource
glib-compile-resources --target /usr/share/gnome-shell/gnome-shell-theme.gresource --sourcedir /home/$username/shell-theme/theme /home/$username/shell-theme/theme/gnome-shell-theme.gresource.xml
rm -rf /home/$username/shell-theme
rm -rf /home/$username/extractgst.sh

## VM SETUP
if [ "$vm" = true ]; then
    # Gnome settings
    sudo -Hu $username dbus-launch --exit-with-session gsettings set org.gnome.desktop.session idle-delay 0
    # SSH
    printf "\n\nConfiguring SSH... \n"
    echo "
    HostKey /etc/ssh/ssh_host_ed25519_key
    PermitRootLogin no
    PasswordAuthentication no
    MaxAuthTries 10" >> /etc/ssh/sshd_config
    systemctl enable sshd.service
    if [ -n "$ssh_key" ]; then
        sudo -Hu $username echo $ssh_key > /home/$username/.ssh/authorized_keys
        chmod 600 /home/$username/.ssh/authorized_keys
        chown $username:$username /home/$username/.ssh/authorized_keys
    fi
    # RDP
    sudo -Hu gnome-remote-desktop mkdir -p /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/
    sudo -Hu gnome-remote-desktop openssl req -new -newkey rsa:4096 -days 720 -nodes -x509 -subj /C=SE/ST=NONE/L=NONE/O=GNOME/CN=gnome.org -out /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.crt -keyout /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.key
    cp /usr/bin/pkexec /usr/bin/pkexec.bk
    ln -sf /usr/bin/sudo /usr/bin/pkexec
    grdctl --system rdp set-tls-key /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.key
    grdctl --system rdp set-tls-cert /var/lib/gnome-remote-desktop/.local/share/gnome-remote-desktop/tls.crt
    grdctl --system rdp set-credentials "rdp" "$rdppass"
    grdctl --system rdp enable # FIX
    mv /usr/bin/pkexec.bk /usr/bin/pkexec
    systemctl enable gnome-remote-desktop.service
    # VM Tools
    pacman --noconfirm -Sy open-vm-tools
    systemctl enable vmtoolsd
    systemctl enable vmware-vmblock-fuse
fi
' >> /mnt/nemesis.sh

# Chroot and run stage 2 script
printf "\n\nRunning stage 2..."
chmod +x /mnt/nemesis.sh
arch-chroot /mnt ./nemesis.sh
rm /mnt/nemesis.sh
umount /mnt/boot
umount /mnt
sleep 5
