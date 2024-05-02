#!/bin/bash
# this will install arch linux with linux-hardened kernel and hyprland
# will boot with efistub


# Ask the user if they want to continue
echo "You need to connect to the internet before starting this script! Run nmtui for interactive menu & You need to setup 3 partitions. One fat32 with esp flag ~500MB; one swap partition and one root partition ext4."
echo -n "Do you want to continue? (Y/n) "
read answer
if [[ "$answer" == "y" ]] || [[ -z "$answer" ]]; then
    echo "You chose to continue."
else
    echo "Aborting..."
    exit 1
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
read -p "Enter encrypted swap partition (e.g., /dev/sda2): " swap_partition
read -p "Enter encrypted root partition (e.g., /dev/sda3): " root_partition
# timedatectl

# Setting up partitions
#root
cryptsetup -y -v luksFormat $root_partition
cryptsetup open $root_partition root
mkfs.ext4 /dev/mapper/root

#swap
mkfs.ext2 -L cryptswap $swap_partition 1M

#boot
mkfs.fat -F 32 $efistub_partition

#mount
mount /dev/mapper/root /mnt
mount --mkdir $efistub_partition /mnt/efi

#gen root
pacman-key --init
pacman-key --populate archlinux
pacstrap -K /mnt base linux-hardened linux-firmware
echo "swap         UUID=$(blkid -s UUID -o value $swap_partition)     /dev/urandom            swap,offset=2048,cipher=aes-xts-plain64,size=512" >> /mnt/etc/crypttab
echo "/dev/mapper/swap  none   swap    defaults   0       0" >> /mnt/etc/fstab
echo "cryptdevice=UUID=$(blkid -s UUID -o value $root_partition):recrypt root=/dev/mapper/recrypt resume=/dev/mapper/swap rw loglevel=0 quiet lsm=landlock,lockdown,yama,integrity,apparmor,bpf lockdown=integrity slab_nomerge init_on_alloc=1 init_on_free=1 mce=0  mds=full,nosmt module.sig_enforce=1 oops=panic mitigations=auto,nosmt audit=1 intel_iommu=on page_alloc.shuffle=1 pti=on randomize_kstack_offset=on vsyscall=none debugfs=off ipv6.disable=1">/mnt/etc/kernel/cmdline
echo "proc /proc proc nosuid,nodev,noexec,hidepid=2,gid=proc 0 0">>/mnt/etc/fstab
echo "/dev/mapper/recrypt     /               ext4            rw,relatime     0 1">>/mnt/etc/fstab
echo "PARTUUID=$(blkid -s PARTUUID -o value $efistub_partition)           /efi            vfat            rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,shortname=mixed,utf8,errors=remount-ro     0 2">>/mnt/etc/fstab

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
pacman -S --noconfirm sbctl efibootmgr
sed -i 's/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/g' \"/etc/mkinitcpio.conf\"
sed -i \"2iecho -e '\\\\\033[?1c'\" \"/usr/lib/initcpio/hooks/encrypt\"
sed -i 's/A password is required to access the \${cryptname} volume:/Hey bro you found my laptop pls email me :)/g' \"/usr/lib/initcpio/hooks/encrypt\"
sed -i 's/Enter passphrase for %s:/notsungod@cock.li       /g' \"/bin/cryptsetup\"
mkinitcpio -P
mkdir -p /efi/EFI/arch
sbctl bundle --kernel-img /boot/vmlinuz-linux-hardened --initramfs /boot/initramfs-linux-hardened.img --save /efi/EFI/arch/arch.efi
efistub_partition=$(mount | grep -E '/efi ' | awk '{print $1}')
efibootmgr --create --disk /dev/$(lsblk -no pkname $efistub_partition) --part $(lsblk -no NAME $efistub_partition | grep -oE '[0-9]+$') --label \"arch\" --loader '\EFI\arch\arch.efi' --unicode
useradd -m user
usermod -aG wheel tokyo
passwd -l root
echo \"umask 0077\">>/etc/profile
pacman -S --noconfirm git networkmanager tmux sudo btop noto-fonts-emoji ttf-fira-code glibc upower fastfetch base-devel gcc
echo \"Enter ROOT password: \"
passwd
echo \"Enter password for new user (user): \"
passwd user
echo '%wheel ALL=(ALL:ALL) ALL' | EDITOR='tee -a' visudo
echo 'Defaults lecture=never' | EDITOR='tee -a' visudo
echo '[main]'>>/etc/NetworkManager/NetworkManager.conf
echo 'plugins=keyfile'>>/etc/NetworkManager/NetworkManager.conf
echo 'persistent=true'>>/etc/NetworkManager/NetworkManager.conf
"
# Finish
echo "Setup completed successfully! You can REBOOT now."