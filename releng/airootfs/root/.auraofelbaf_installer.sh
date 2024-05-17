#!/bin/bash
# this will install arch linux with linux-hardened kernel and hyprland
# will boot with efistub


# Ask the user if they want to continue
echo "You need to connect to the internet before starting this script! Run nmtui for interactive menu & You need to setup 2 partitions. One fat32 with esp flag ~500MB; one root partition ext4."
echo -n "Do you want to continue? (Y/n) "
read answer
if [[ "$answer" == "y" ]] || [[ -z "$answer" ]]; then
    echo "You chose to continue."
else
    echo "Aborting..."
    exit 1
fi

# Specify DE
echo -n "Choose your desired Configuraion: h=Hyprland(default) , m=minimalistic , x=xfce4: "
read answer
if [[ "$answer" == "m" ]]; then
    echo "You chose to minimalistic download."
    minimalistic=1
    xfce=0
    hypr=0
fi
if [[ "$answer" == "x" ]]; then
    echo "You chose to xfce4 download."
    minimalistic=0
    xfce=1
    hypr=0
else
    echo "You chose to Hyprland download."
    minimalistic=0
    xfce=0
    hypr=1
fi

# Specify DE
echo -n "Choose your desired Configuraion: iuselibreboot=encryptedboot , s=efistub(default): "
read answer
if [[ "$answer" == "iuselibreboot" ]]; then
    echo "You chose to encrypted /boot download."
    encboot=1
    efist=0
else
    encboot=0
    efist=1
    echo "You chose efistub download."
fi

echo "Checking platform size..."
echo -n "Platform Size: "
cat /sys/firmware/efi/fw_platform_size

echo "Checking internet connection..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "You are connected to the internet!"
else
    echo "[ERROR] Not connected to the internet. Aborting..."
fi

# Define partitions
lsblk
read -p "Enter EFISTUB boot partition (e.g., /dev/sda1): " efistub_partition
read -p "Enter encrypted root partition (e.g., /dev/sda2): " root_partition
# timedatectl

# create key-file
[ $encboot == 1 ] && dd bs=512 count=4 if=/dev/urandom of=./notnothing iflag=fullblock

# Setting up partitions
#root

[ $encboot == 1 ] && cryptsetup -y -v luksFormat $root_partition ./notnothing
[ $encboot == 1 ] && cryptsetup open $root_partition root --key-file ./notnothing

[ $efist == 1 ] && cryptsetup -y -v luksFormat $root_partition
[ $efist == 1 ] && cryptsetup open $root_partition root
mkfs.ext4 /dev/mapper/root

#boot
[ $efist == 1 ] && mkfs.fat -F 32 $efistub_partition

[ $encboot == 1 ] && cryptsetup -y -v luksFormat $efistub_partition
[ $encboot == 1 ] && cryptsetup open $efistub_partition boot
[ $encboot == 1 ] && mkfs.fat -F 32 /dev/mapper/boot

#mount
mount /dev/mapper/root /mnt

[ $efist == 1 ] && mount --mkdir $efistub_partition /mnt/efi
[ $encboot == 1 ] && mount --mkdir /dev/mapper/boot /mnt/boot


# move key-file to chroot
[ $encboot == 1 ] && mkdir /mnt/etc
[ $encboot == 1 ] && mv ./notnothing /mnt/etc/

#gen root
pacman-key --init
pacman-key --populate archlinux
pacstrap -K /mnt base linux-hardened linux-firmware
echo "proc /proc proc nosuid,nodev,noexec,hidepid=2,gid=proc 0 0">>/mnt/etc/fstab

[ $efist == 1 ] && echo "cryptdevice=UUID=$(blkid -s UUID -o value $root_partition):recrypt root=/dev/mapper/recrypt rw loglevel=0 quiet lsm=landlock,lockdown,yama,integrity,apparmor,bpf lockdown=integrity slab_nomerge init_on_alloc=1 init_on_free=1 mce=0  mds=full,nosmt module.sig_enforce=1 oops=panic mitigations=auto,nosmt audit=1 intel_iommu=on page_alloc.shuffle=1 pti=on randomize_kstack_offset=on vsyscall=none debugfs=off ipv6.disable=1">/mnt/etc/kernel/cmdline
[ $efist == 1 ] && echo "/dev/mapper/recrypt     /               ext4            rw,relatime     0 1">>/mnt/etc/fstab
[ $efist == 1 ] && echo "PARTUUID=$(blkid -s PARTUUID -o value $efistub_partition)           /efi            vfat            rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro     0 2">>/mnt/etc/fstab

#chroot
arch-chroot /mnt /bin/bash -c "
pacman-key --init
pacman-key --populate archlinux
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc
echo \"en_US.UTF-8 UTF-8\">>/etc/locale.gen
locale-gen
echo \"LANG=en_US.UTF-8\">>/etc/locale.conf
echo \"KEYMAP=de-latin1\">>/etc/vconsole.conf
echo \"host\">>/etc/hostname
sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/g' \"/etc/mkinitcpio.conf\"
"

if [ $encboot == 1 ];then
arch-chroot /mnt /bin/bash -c "
sed -i 's/FILES=()/FILES=\"\/etc\/notnothing\"/g' \"/etc/mkinitcpio.conf\"
mkinitcpio -P
"
fi

if [ $efist == 1 ];then
arch-chroot /mnt /bin/bash -c "
pacman -S --noconfirm sbctl efibootmgr
sed -i \"2iecho -e '\\\\\033[?1c'\" \"/usr/lib/initcpio/hooks/encrypt\"
sed -i 's/A password is required to access the \${cryptname} volume:/Hey bro you found my laptop pls email me :)/g' \"/usr/lib/initcpio/hooks/encrypt\"
sed -i 's/Enter passphrase for %s:/notsungod@cock.li       /g' \"/bin/cryptsetup\"
mkinitcpio -P
mkdir -p /efi/EFI/arch
sbctl bundle --kernel-img /boot/vmlinuz-linux-hardened --initramfs /boot/initramfs-linux-hardened.img --save /efi/EFI/arch/arch.efi
efistub_partition=$(mount | grep -E '/efi ' | awk '{print $1}')
efibootmgr --create --disk /dev/$(lsblk -no pkname $efistub_partition) --part $(lsblk -no NAME $efistub_partition | grep -oE '[0-9]+$') --label \"arch\" --loader '\EFI\arch\arch.efi' --unicode
"
fi
arch-chroot /mnt /bin/bash -c "
useradd -m tokyo
usermod -aG wheel tokyo
passwd -l root
echo \"umask 0077\">>/etc/profile
pacman -S --noconfirm neovim firefox git starship networkmanager tmux sudo noto-fonts-emoji ttf-fira-code sxiv glibc upower fastfetch btop base-devel gparted gcc openssh unclutter
echo \"Enter ROOT password: \"
passwd
echo \"Enter password for new user (tokyo): \"
passwd tokyo
echo '%wheel ALL=(ALL:ALL) ALL' | EDITOR='tee -a' visudo
echo 'Defaults lecture=never' | EDITOR='tee -a' visudo
echo '[main]'>>/etc/NetworkManager/NetworkManager.conf
echo 'plugins=keyfile'>>/etc/NetworkManager/NetworkManager.conf
echo 'persistent=true'>>/etc/NetworkManager/NetworkManager.conf
"
[ $encboot == 1 ] && chmod 000 /mnt/etc/notnothing
if [ $xfce == 1 ];then
arch-chroot /mnt /bin/bash -c "
pacman -S --noconfirm xfce4 xorg-server
"
fi

arch-chroot /mnt su - tokyo << 'EOF'
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si --noconfirm
cd
rm -rf yay
yay --version
echo ".cfg" >> .gitignore
git clone -q --bare https://github.com/notsungod/dotfiles $HOME/.cfg
rm .bashrc
/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME checkout
/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME config --local status.showuntrackedfiles no
git clone https://github.com/gpakosz/.tmux.git
ln -s ".tmux/.tmux.conf" "$HOME/.config/tmux/tmux.conf"
git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm
exit
EOF

if [ $hypr == 1 ];then
arch-chroot /mnt /bin/bash -c "
pacman -S --noconfirm hyprland kitty waybar python-pywal
yay -S --noconfirm swww python-pywalfox
echo Hyprland >> ~/.bash_profile
"
fi

if [ $xfce == 1 ]; then
arch-chroot /mnt su - tokyo << 'EOF'
mv ~/.config/dotxfce4/ ~/.config/xfce4
echo "[ pgrep xinit ] || startxfce4">> ~/.bash_profile
EOF
fi



arch-chroot /mnt /bin/bash -c "
cp -rl /home/tokyo/.config/.outsideofhome/* /
"
# Finish
echo "Setup completed successfully! You can REBOOT now."
