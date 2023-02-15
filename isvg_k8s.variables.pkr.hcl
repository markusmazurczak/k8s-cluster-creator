variable "country_code" {
  type    = string
  default = "DE"
}

variable "zoneinfo" {
  type    = string
  default = "Europe/Berlin"
}

variable "iso_url" {
  type    = string
  default = "https://ftp.halifax.rwth-aachen.de/archlinux/iso/2023.01.01/archlinux-2023.01.01-x86_64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "file:file:https://ftp.halifax.rwth-aachen.de/archlinux/iso/2023.01.01/sha256sums.txt"
}

variable "os_user" {
  type    = string
  default = "isvg"
}

#size in MB
variable "hdd_size" {
  type    = number
  default = 10000
}

variable "num_of_cpus-control-plane" {
  type    = number
  default = 2
}

#size in MB
variable "mem_size-control-plane" {
  type    = number
  default = 4096
}

variable "hostname-control-plane" {
  type    = string
  default = "isvg_k8s-control"
}
variable "node_network_ip_master" {
  type    = string
  default = "192.168.10.10/24"
}

variable "num_of_cpus-worker" {
  type    = number
  default = 1
}

#size in MB
variable "mem_size-worker" {
  type    = number
  default = 2048
}

variable "hostname-worker" {
  type    = string
  default = "isvg_k8s-worker"
}

variable "node_network_ip_worker" {
  type    = string
  default = "192.168.10.11/24"
}

variable "shared_folder_hostsystem_path" {
  type = string
}

variable "pod_network_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "node_network_cidr" {
  type    = string
  default = "192.168.10.0/24"
}

variable "nodeport_network_cidr" {
  type    = string
  default = "192.168.15.0/24"
}

variable "node_network_iface_name" {
  type    = string
  default = "enp0s8"
}

variable "nodeport_iface_name" {
  type    = string
  default = "enp0s9"
}

variable "nodeport_hostdevice_name" {
  type    = string
  default = "VirtualBox Host-Only Ethernet Adapter #3"
}