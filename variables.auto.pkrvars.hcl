country_code = "DE"
zoneinfo     = "Europe/Berlin"

iso_url      = "https://ftp.halifax.rwth-aachen.de/archlinux/iso/2023.01.01/archlinux-2023.01.01-x86_64.iso"
iso_checksum = "file:https://ftp.halifax.rwth-aachen.de/archlinux/iso/2023.01.01/sha256sums.txt"
os_user      = "isvg"

hdd_size                  = 10000
num_of_cpus-control-plane = 8
mem_size-control-plane    = 16384
num_of_cpus-worker        = 4
mem_size-worker           = 4096
hostname-control-plane    = "isvg-k8s-control"
hostname-worker           = "isvg-k8s-worker"
pod_network_cidr          = "10.10.0.0/24"
node_network_cidr         = "192.168.10.0/24"
nodeport_network_cidr     = "192.168.15.0/24"
node_network_ip_master    = "192.168.10.10/24"
node_network_ip_worker    = "192.168.10.11/24"
node_network_iface_name   = "enp0s8"
nodeport_iface_name       = "enp0s9"
nodeport_hostdevice_name  = "VirtualBox Host-Only Ethernet Adapter #3"

shared_folder_hostsystem_path = "C:\\Users\\Markus\\Desktop\\share"