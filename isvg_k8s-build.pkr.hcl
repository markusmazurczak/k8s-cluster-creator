build {
  name = "build_basicvm"
  sources = [
    "sources.virtualbox-iso.basic_vm"
  ]

  provisioner "shell" {
    script = "kickstart_scripts/kickstart_vbox-base.sh"
    environment_vars = [
      "VM_HOSTNAME=base-image",
      "COUNTRYCODE=${var.country_code}",
      "ZONEINFO=${var.zoneinfo}",
      "VM_USER=${var.os_user}"
    ]
  }
}

build {
  name = "build_k8s_basic_conf"
  sources = [
    "sources.virtualbox-ovf.k8s-basic_conf"
  ]

  provisioner "shell" {
    script = "kickstart_scripts/k8s_base-conf.sh"
    environment_vars = [
      "VM_HOSTNAME=k8s-basic"
    ]
  }
}

build {
  name = "build_k8s_master_conf"
  sources = [
    "sources.virtualbox-ovf.k8s-master_conf"
  ]

  provisioner "shell" {
    script = "kickstart_scripts/k8s_master-conf.sh"
    environment_vars = [
      "VM_HOSTNAME=${var.hostname-control-plane}",
      "VM_SHARE_NAME=vm-build-share",
      "POD_NETWORK_CIDR=${var.pod_network_cidr}",
      "NODE_NETWORK_CIDR=${var.node_network_cidr}",
      "K8S_NODE_IP=${var.node_network_ip_master}",
      "NODE_NETWORK_IFACE_NAME=${var.node_network_iface_name}",
      "NODEPORT_IFACE_NAME=${var.nodeport_iface_name}",
      "NODEPORT_HOSTDEVICE_NAME=${var.nodeport_hostdevice_name}"
    ]
  }
}

build {
  name = "build_k8s_worker_conf"
  sources = [
    "sources.virtualbox-ovf.k8s-worker_conf"
  ]

  provisioner "shell" {
    script = "kickstart_scripts/k8s_worker-conf.sh"
    environment_vars = [
      "MASTER_HOSTNAME=${var.hostname-control-plane}",
      "VM_HOSTNAME=${var.hostname-worker}",
      "VM_SHARE_NAME=vm-build-share",
      #"POD_NETWORK_CIDR=${var.pod_network_cidr}",
      "K8S_MASTER_IP=${var.node_network_ip_master}",
      "K8S_NODE_IP=${var.node_network_ip_worker}",
      "NODE_NETWORK_IFACE_NAME=${var.node_network_iface_name}",
      "NODEPORT_IFACE_NAME=${var.nodeport_iface_name}",
      "NODEPORT_HOSTDEVICE_NAME=${var.nodeport_hostdevice_name}"
    ]
  }
}