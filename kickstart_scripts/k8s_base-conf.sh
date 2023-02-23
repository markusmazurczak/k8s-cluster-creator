#!/bin/bash

#Install stuff
sudo pacman -S --noconfirm devtools base-devel containerd vi

#Install AUR package helper "yay"
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg --noconfirm -si
cd

#Install etcd
yay -S --noconfirm etcd

#Install more stuff
sudo pacman -S --noconfirm kubelet kubeadm kubectl runc cni-plugins ethtool ebtables socat conntrack-tools helm virtualbox-guest-utils-nox sysstat vim nfs-utils
sudo systemctl enable --now vboxservice

#Configure iptables to see bridged traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

#Configure containerd runtime
sudo mkdir /etc/containerd
sudo bash -c 'containerd config default > /etc/containerd/config.toml'
sudo bash -c "sed 's/SystemdCgroup = false/SystemdCgroup = true/' -i /etc/containerd/config.toml"

#Enable containerd as systemd service
sudo systemctl enable --now containerd

sudo systemctl disable dhcpcd
sudo systemctl stop dhcpcd

#Set static IP on NAT iface
sudo bash -c "cat <<EOF >/etc/systemd/network/enp0s3.network
[Match]
Name=enp0s3

[Network]
Address=10.0.2.15/24
Gateway=10.0.2.2
DHCP=no
EOF"
sudo systemctl enable systemd-networkd