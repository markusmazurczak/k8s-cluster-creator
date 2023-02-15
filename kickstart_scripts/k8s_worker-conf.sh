#!/bin/bash

#Set static IP to NATNetwork iface
sudo bash -c "cat <<EOF >/etc/systemd/network/${NODE_NETWORK_IFACE_NAME}.network
[Match]
Name=${NODE_NETWORK_IFACE_NAME}

[Network]
Address=${K8S_NODE_IP}
Gateway=${K8S_NODE_IP%.*/*}.1
DHCP=no
EOF"

sudo systemctl enable --now dhcpcd@enp0s3
sudo systemctl enable --now dhcpcd@enp0s9
sudo networkctl reload
sudo networkctl reconfigure ${NODE_NETWORK_IFACE_NAME}
sudo networkctl up ${NODE_NETWORK_IFACE_NAME}
sleep 10

#Set the hostname
sudo hostnamectl hostname ${VM_HOSTNAME}
sudo bash -c "echo ${K8S_MASTER_IP%/*} ${MASTER_HOSTNAME} >> /etc/hosts"
sudo bash -c "echo ${K8S_NODE_IP%/*} ${VM_HOSTNAME} >> /etc/hosts"

sudo systemctl enable --now kubelet

#Mount the shared-folder
sudo mkdir /mnt/share
sudo chown $(id -u):$(id -g) /mnt/share
sudo mount -t vboxsf ${VM_SHARE_NAME} /mnt/share

echo "Worker-Node ${VM_HOSTNAME}- IP Configuration" > /mnt/share/k8s_cluster_ipconfig-${VM_HOSTNAME}.txt
echo "=====================================" >> /mnt/share/k8s_cluster_ipconfig-${VM_HOSTNAME}.txt
ip addr >> /mnt/share/k8s_cluster_ipconfig-${VM_HOSTNAME}.txt

cp /mnt/share/pod_join_cmd ~/
chmod 740 ~/pod_join_cmd

sudo ~/pod_join_cmd