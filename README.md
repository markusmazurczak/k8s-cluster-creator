# Kubernetes Setup
This readme guides you through the process of setting up an preconfigured kubernetes environment. This environment consists out of multiple VirtualBox Images.
Because I was too lazy to script everything there are one or two prerequisites that you have to execute manually in advance.

The images are build using HashiCorp's Packer so you can re-configure everything you need to change the VM's as long as you know what you do ;). But I recommend
to use the build-Script which takes care of populating worker nodes to the cluster by starting the control node etc....

***At the moment there is only a build.ps1 script for windows powershell. As soon as there is some more time I will write one for Linux using bash***

# K8S Networking
Using these build-scripts will configure a cluster environment with some networks which will be explained hereafter
## POD Network
The internal POD-Network which all Pods use to communicate internaly. I use [Calico](https://www.tigera.io/project-calico/) as the CNI-Plugin and calicoctl is also installed in the control-plane image.
## NATNetwork
For Node-Communication I use an VBox Managed NATNatwork.
## Node-Port-Network
Because the cluster these scripts create are for developement or administrative purposes there is no ingress controller. I use the NodePort-Service to make services accessible.

# Prerequisites
## Install VirtualBox
https://www.virtualbox.org/
## Install HasiCorp Packer
Make sure it is in your PATH.
https://www.packer.io/
## Create VirtualBox NAT-Network
To get the k8s control-plane and worker nodes properly communicating I decided to do this using a VBox NAT-Network with static IP's.
As default I use the following Network: 192.168.10.0/24. 

If you already used this network you have to choose another one and configure the variable **node_network_cidr** in file **build_params.json**.
To check your existing VBox NAT-Networks execute the following command:
```
VBoxManage.exe list natnetworks
```
To configure the needed NAT-Network execute the following command:
```
VBoxManage.exe natnetwork add --netname k8scluster --network 192.168.10.0/24 --enable --dhcp off
```
**Do not change the --netname value**
## Create an NodePort-Network
To access services in your cluster I decided to use the NodePort ServiceType. To do this I choose a VirtualBox Host-Only Network. To configure it, execute the following command:
```
VBoxManage.exe hostonlyif create
```
This will create an virtual interface in your host system and the output in my case on windows is something like:
```
PS C:\Users\Markus\Programming\isvg_k8s_vbox> C:\Programme\Oracle\VirtualBox\VBoxManage.exe hostonlyif create
0%...10%...20%...30%...40%...50%...60%...70%...80%...90%...100%
Interface 'VirtualBox Host-Only Ethernet Adapter #4' was successfully created
```
In this example a new interface named "VirtualBox Host-Only Ethernet Adapter #4" was created.
It is important that this name is configured as the value of the variable **nodeport_hostdevice_name** in **build_params.json**.

After creating the new virtual interface you have to configure the automatically created DHCP-Server to your needs.
To do that execute:
```
VBoxManage.exe dhcpserver modify --interface "VirtualBox Host-Only Ethernet Adapter #4" --server-ip=192.168.15.2 --netmask=255.255.255.0 --lower-ip=192.168.15.100 --upper-ip=192.168.15.254 --enable
```
Make sure to set
- *interface* To the name of the virtual interface you created before
- And the IP Adresses as you want to but make sure to set the attribut **nodeport_network_cidr** in **build_params.json** to values matching your DHCP range in CIDR format
If this command throws an error because the DHCP Server is not existing, simply replace *modify* with *add*:
```
VBoxManage.exe dhcpserver add --interface "VirtualBox Host-Only Ethernet Adapter #4" --server-ip=192.168.15.2 --netmask=255.255.255.0 --lower-ip=192.168.15.100 --upper-ip=192.168.15.254 --enable
```
# Configuration
Before you execute the build-script, modify the file **build_params.json** to your needs.
| Attribute | Description |
|   ---     |      ---    |
| country_code | Choose the code for the country you are executing the script. The country code is used to determine the nearest Arch Linux-Pacman mirror location for downloading needed packages |
| zoneinfo | Insert your timezone in the format *Zone/Subzone* |
| iso.url | Normaly you dont have to modify this attribute. It tells packer which ISO to download for creating the appliances |
| iso.checksum | Normaly you dont have to modify this attribute. It points to the ISO-Image checksum file |
| username | The user which will be configured in the operating system. Use this username to SSH-Connect into the appliances. **The Password is always the username**. |
| hdd_size | Configure the disksize with which every image is created in MB |
| network.pod_network_cidr | This is the internal POD-Network. No need to modify anything here |
| network.node_network_cidr | This is the [NATNetwork](#Create-VirtualBox-NAT-Network) you configured earlier |
| network.nodeport_network_cidr | This is the [NodePort-Network](#Create-an-NodePort-Network) you created earlier. Make sure that this network is not used. Every Cluster-Worker will get an IP from that range and using this IP you can access services without any further ingress controller. |
| network.node_network_iface_name | Do not modify this value until you have to because the interfaces will be named different in the images you created. This attribute holds the name of the interface which is used for the Node-Network |
| network.nodeport_iface_name | Do not modify this value until you have to because the interfaces will be named different in the images you created. This attribute holds the name of the interface which is used for the NodePort-Network |
| network.nodeport_hostdevice_name | Insert the name of the HostOnly Device you created during creating an [NodePort-Network](#Create-an-NodePort-Network) |
| control_node.num_of_cpus | Number of CPUs your control-plane node should use |
| control_node.mem_size | Memory size in MB for the control-plane node appliance |
| control_node.hostname | Hostname of the control-plane node |
| control_node.node_network_ip | Node-Network IP of the control-plane node in CIDR format |
| worker_nodes.num_of_cpus | Number of CPUs your worker node should use |
| worker_nodes.mem_size | Memory size in MB for the worker node appliance |
| worker_nodes.hostname | Hostname of the worker node |
| worker_nodes.node_network_ip | Node-Network IP of the worker node in CIDR format |
| shared_folder | Insert a folder which you have access to which the script can use to save appliance IP address information for you, which is used to transfer information for populating nodes to the cluster and for saving a temporary ssh keypair |

The **worker_nodes** attributes holds an array of worker-node configurations. That means that if you specify 10 worker-node configurations, than 10 VMs will be build as workers and populated into the cluster producing 10 images.

# Create Images
```
Usage: .\build.ps1 -target TARGET [-only]

Possible targets:
    all - Builds everything
    linux_base - Builds an VirtualBox image with an basic installed Arch-Linux
    k8s_base - Takes the image build with target vbox_base and does the kubernetes basic configuration
    master - Takes kubernetes base image and configures it as the kubernetes control plane node
    worker - Takes kubernetes base image, configures it as a worker node and populates that worker into the cluster

-only is an optional parameter which tells the build process to NOT build all up until the given target.
To understand that you need to know the dependencies of the builds:
    First build: The basic build is target "vbox_base".
    Second build: The target "base" uses the image produces by target "vbox_base" and produces another one
    Third build(master): The target "master" uses the image produced by target "base" and produces a running image with an full kubernetes control plane mode
    Third build(worker): The target "worker" uses the image produced by target "base" and produces a running image with an full kubernetes worker node which is clustered with the control plane node
This means for example that if you specify target "master" without the "-only" option, the complete build process will start. First "linux_base" will be created, then "k8s_base" and then "master"
If you just want to create the "master" image without build all dependend images input the "-only" option. This assumes that all previous and needed build are already there
DONT FORGET TO CONFIGURE build.params.json TO YOUR NEED
EVERY IMAGE ALREADY CREATED WILL BE DELETED WHEN EXECUTING
```
***Always make sure that you are executing the script from the directory where it is located because the script only assumes relative paths***

During the process of creating all images there will pop up some VirtualBox windows and temp images will be imported and exported. Please do not close the windows or delete the imported images. If everything goes well, all windows will be closed and all imported images will be deleted.
## Image location
The created images are located in the **images** folder.
You can find your control-plane image in folder: **images\k8s-control-plane**.
You can find all your configured worker-nodes in folder: **images\worker**.

Than import the appliances in your VirtualBox and you are good to go. To access the imported appliances configure a ssh port-forwarding into the machine and use the configured username as username and password.

# Test the cluster
Some usefull commands to get the status of the cluster after all VMs are started. Everything should be executed on the control-plane node.
Get the status of all nodes:
```
[kubuser@k8s-control ~]$ kubectl get nodes -A -o wide
NAME           STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE     KERNEL-VERSION   CONTAINER-RUNTIME
k8s-control    Ready    control-plane   18h   v1.26.1   192.168.10.10   <none>        Arch Linux   6.1.11-arch1-1   containerd://1.6.16
k8s-worker-1   Ready    <none>          17h   v1.26.1   192.168.10.11   <none>        Arch Linux   6.1.11-arch1-1   containerd://1.6.16
k8s-worker-2   Ready    <none>          17h   v1.26.1   192.168.10.12   <none>        Arch Linux   6.1.11-arch1-1   containerd://1.6.16
k8s-worker-3   Ready    <none>          17h   v1.26.1   192.168.10.13   <none>        Arch Linux   6.1.11-arch1-1   containerd://1.6.16
```
Get the status of all pods:
```
[kubuser@k8s-control ~]$ kubectl get pods -A -o wide
NAMESPACE     NAME                                      READY   STATUS    RESTARTS      AGE   IP              NODE           NOMINATED NODE   READINESS GATES
default       nginx-deployment-69549f9c78-8knfk         1/1     Running   1 (86s ago)   17h   10.10.0.130     k8s-worker-2   <none>           <none>
default       nginx-deployment-69549f9c78-j5pgw         1/1     Running   1 (90s ago)   17h   10.10.0.66      k8s-worker-3   <none>           <none>
default       nginx-deployment-69549f9c78-l9rld         1/1     Running   1 (16h ago)   17h   10.10.0.194     k8s-worker-1   <none>           <none>
kube-system   calico-kube-controllers-57b57c56f-cpz54   1/1     Running   3 (16h ago)   18h   10.10.0.11      k8s-control    <none>           <none>
kube-system   calico-node-4j7j2                         1/1     Running   1 (90s ago)   17h   192.168.10.13   k8s-worker-3   <none>           <none>
kube-system   calico-node-f2jx5                         1/1     Running   2 (16h ago)   17h   192.168.10.11   k8s-worker-1   <none>           <none>
kube-system   calico-node-qhnn6                         1/1     Running   1 (16h ago)   17h   192.168.10.12   k8s-worker-2   <none>           <none>
kube-system   calico-node-s6ff8                         1/1     Running   3 (16h ago)   18h   192.168.10.10   k8s-control    <none>           <none>
kube-system   coredns-787d4945fb-77pdh                  1/1     Running   3 (86s ago)   18h   10.10.0.12      k8s-control    <none>           <none>
kube-system   coredns-787d4945fb-kxdt8                  1/1     Running   3 (86s ago)   18h   10.10.0.10      k8s-control    <none>           <none>
kube-system   etcd-k8s-control                          1/1     Running   3 (16h ago)   18h   192.168.10.10   k8s-control    <none>           <none>
kube-system   kube-apiserver-k8s-control                1/1     Running   3 (16h ago)   18h   192.168.10.10   k8s-control    <none>           <none>
kube-system   kube-controller-manager-k8s-control       1/1     Running   3 (16h ago)   18h   192.168.10.10   k8s-control    <none>           <none>
kube-system   kube-proxy-7hpck                          1/1     Running   3 (16h ago)   18h   192.168.10.10   k8s-control    <none>           <none>
kube-system   kube-proxy-hg8j6                          1/1     Running   1 (90s ago)   17h   192.168.10.13   k8s-worker-3   <none>           <none>
kube-system   kube-proxy-nprsp                          1/1     Running   1 (86s ago)   17h   192.168.10.12   k8s-worker-2   <none>           <none>
kube-system   kube-proxy-qg4vd                          1/1     Running   2 (16h ago)   17h   192.168.10.11   k8s-worker-1   <none>           <none>
kube-system   kube-scheduler-k8s-control                1/1     Running   3 (16h ago)   18h   192.168.10.10   k8s-control    <none>           <none>
```
To test the working NodePort-Service there is a **nginx.yaml** in the home folder of your user at the control-plane node which you can apply to the cluster using the command:
```
[kubuser@k8s-control ~]$ kubectl apply -f nginx.yaml
deployment.apps/nginx-deployment created
service/nginx-service-np created
```
This will install Eco-Service which you can call for example in your browser. Just use an NodePort IP of one of your workers and use port 30000.
## NodePort IPs
Because the IPs of the NodePort Service are assigned using DHCP the build-script will output the IP configuration in node-specific txt files in the folder you configured as your shared folder (variable **shared_folder** in **build_params.json**).
The interface which "holds" the NodePort IP is the one you configured in variable **nodeport_iface_name**. It's default will be enp0s9.
# Errors
If an error occurs. Just start the process of creation again. The script is not failsafe and most of the time it will be clean up afterwards.

Some error's I've seen so far:
- IO Hickup in host which leads to longer running processes and timeouts
- Partial DNS failure during pacman resolves
- CPU Stuck-Bug in VBox
# Build time
Just to give you an idea of how long it could take to create a cluster with one control-plane-node and 3 workers from scratch (the arch linux was already downloaded) with the following configuration:
```json
{
    "country_code": "DE",
    "zoneinfo": "Europe/Berlin",
    "iso": {
        "url": "http://ftp.halifax.rwth-aachen.de/archlinux/iso/latest/archlinux-x86_64.iso",
        "checksum": "file:http://ftp.halifax.rwth-aachen.de/archlinux/iso/latest/sha256sums.txt"
    },
    "username": "kubuser",
    "hdd_size": 20000,
    "network": {
        "pod_network_cidr": "10.10.0.0/24",
        "node_network_cidr": "192.168.10.0/24",
        "nodeport_network_cidr": "192.168.15.0/24",
        "node_network_iface_name": "enp0s8",
        "nodeport_iface_name": "enp0s9",
        "nodeport_hostdevice_name": "VirtualBox Host-Only Ethernet Adapter #3"
    },
    "control_node": {
        "num_of_cpus": 6,
        "mem_size": 16384,
        "hostname": "k8s-control",
        "node_network_ip": "192.168.10.10/24"
    },
    "worker_nodes": [
        {
            "num_of_cpus": 2,
            "mem_size": 8192,
            "hostname": "k8s-worker-1",
            "node_network_ip": "192.168.10.11/24"
        },
        {
            "num_of_cpus": 2,
            "mem_size": 8192,
            "hostname": "k8s-worker-2",
            "node_network_ip": "192.168.10.12/24"
        },
        {
            "num_of_cpus": 2,
            "mem_size": 8192,
            "hostname": "k8s-worker-3",
            "node_network_ip": "192.168.10.13/24"
        }
    ],
    "shared_folder": "C:\\Users\\Markus\\Desktop\\share"
}
```
I am building on an Ryzen 9 5950X with 128GB DDR4 RAM and an Seagate FireCuda 530 NVME in round about 20 Minutes.