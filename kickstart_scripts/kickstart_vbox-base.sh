#!/bin/bash

HDD_DEVICE="/dev/sda"

#fetching actual pacman mirrorlist
MIRRORLIST="https://archlinux.org/mirrorlist/?country=${COUNTRYCODE}&protocol=http&protocol=https&ip_version=4&use_mirror_status=on"
curl -s "${MIRRORLIST}" | sed 's/^#Server/Server/' >/etc/pacman.d/mirrorlist

loadkeys de-latin1-nodeadkeys
timedatectl set-ntp true

#Begin HDD stuff
sgdisk --zap ${HDD_DEVICE}
dd if=/dev/zero of=${HDD_DEVICE} bs=512 count=2048
wipefs --all ${HDD_DEVICE}
sgdisk -n 1:0:0 -c 1:"root" -t 1:8300 ${HDD_DEVICE}
sgdisk ${HDD_DEVICE} -A 1:set:2
mkfs.ext4 -F -m 0 -q ${HDD_DEVICE}1
mount ${HDD_DEVICE}1 /mnt
#End HDD stuff

pacstrap -K /mnt iptables-nft base base-devel linux linux-firmware wget
genfstab -U /mnt >>/mnt/etc/fstab

cat <<EOF >/mnt/base_install.sh 
pacman -S --needed --noconfirm dhcpcd openssh syslinux gptfdisk man-db man-pages
ln -sf /usr/share/zoneinfo/${ZONEINFO} /etc/localtime
sed '/^#en_US\.UTF-8/ s/^#//' -i /etc/locale.gen
sed '/^#de_DE\.UTF-8/ s/^#//' -i /etc/locale.gen
locale-gen
echo 'KEYMAP=de-latin1-nodeadkeys' > /etc/vconsole.conf
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
#echo ${VM_HOSTNAME} > /etc/hostname
#echo "127.0.1.1	${VM_HOSTNAME}.localdomain	${VM_HOSTNAME}" >> /etc/hosts
mkinitcpio -p linux
useradd -m -p \$(openssl passwd -1 "${VM_USER}") ${VM_USER}
usermod -a -G wheel ${VM_USER}

sed "s|sda3|${HDD_DEVICE##/dev/}1|" -i /boot/syslinux/syslinux.cfg
sed 's/TIMEOUT 50/TIMEOUT 5/' -i /boot/syslinux/syslinux.cfg
syslinux-install_update -iam

sed '/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/ s/^# //' -i /etc/sudoers
systemctl enable dhcpcd.service sshd.service systemd-timesyncd.service
EOF

chmod 744 /mnt/base_install.sh
arch-chroot /mnt /base_install.sh
rm /mnt/base_install.sh