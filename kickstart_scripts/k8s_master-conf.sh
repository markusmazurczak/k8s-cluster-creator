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
sudo bash -c "echo ${K8S_NODE_IP%/*} ${VM_HOSTNAME} >> /etc/hosts"

#Mount the shared-folder
sudo mkdir /mnt/share
sudo chown $(id -u):$(id -g) /mnt/share
sudo mount -t vboxsf ${VM_SHARE_NAME} /mnt/share

#Initialize kubeadm
sudo kubeadm config images pull
sudo kubeadm init --node-name=$(hostnamectl hostname) --pod-network-cidr=${POD_NETWORK_CIDR} --apiserver-advertise-address=${K8S_NODE_IP%/*}
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sudo systemctl enable --now kubelet

curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O
sed 's/# - name: CALICO_IPV4POOL_CIDR/- name: CALICO_IPV4POOL_CIDR/' -i calico.yaml
sed "s|#   value: \"192.168.0.0\/16\"|  value: \"${POD_NETWORK_CIDR}\"|" -i calico.yaml
kubectl apply -f calico.yaml

yay -S --noconfirm calicoctl

#Wait max 5 minutes to get all pods started
timeout 5m kubectl wait --for=condition=ready pod --all -A --timeout -1s
if [ $? -ne 0 ]; then
  echo "NOT ALL PODS COULD BE INITIALIZED IN-TIME"
  exit 1
fi

sudo crictl config > /dev/null 2>&1
sudo crictl config --set runtime-endpoint=/run/containerd/containerd.sock

kubeadm token create --print-join-command > /mnt/share/pod_join_cmd

echo "Control-Plane Node ${VM_HOSTNAME} - IP Configuration" > /mnt/share/k8s_cluster_ipconfig-${VM_HOSTNAME}.txt
echo "=====================================" >> /mnt/share/k8s_cluster_ipconfig-${VM_HOSTNAME}.txt
ip addr >> /mnt/share/k8s_cluster_ipconfig-${VM_HOSTNAME}.txt

mkdir ~/.ssh 2> /dev/null
cat /mnt/share/id_rsa.pub >> ~/.ssh/authorized_keys
sudo chmod 400 ~/.ssh/authorized_keys

#place an nginx-nodeport-example service in filesystem
#apply it with "kubectl apply -f nginx.yaml"
cat <<EOF > ~/nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: my-echo
          image: gcr.io/google_containers/echoserver:1.8
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service-np
  labels:
    name: nginx-service-np
spec:
  type: NodePort
  ports:
    - port: 8082        
      targetPort: 8080  
      nodePort: 30000   
      protocol: TCP
      name: http
  selector:
    app: nginx
EOF