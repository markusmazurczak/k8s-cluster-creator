packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.4"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

source "virtualbox-iso" "basic_vm" {
  guest_os_type = "ArchLinux_64"
  iso_url       = "${var.iso_url}"
  iso_checksum  = "${var.iso_checksum}"

  firmware             = "bios"
  ssh_username         = "root"
  ssh_password         = "packer"
  ssh_timeout          = "2m"
  hard_drive_interface = "sata"
  disk_size            = "${var.hdd_size}"
  boot_wait            = "10s"
  vm_name              = "base-img"

  output_directory = "images/base"
  output_filename  = "base-img"

  boot_command = [
    "<enter><wait60>",
    "echo root:packer | chpasswd<enter>"
  ]

  shutdown_command    = "sudo systemctl poweroff"
  post_shutdown_delay = "30s"

  nic_type          = "82540EM"
  gfx_controller    = "vboxsvga"
  gfx_vram_size     = 128
  gfx_accelerate_3d = false

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--memory", 2048],
    ["modifyvm", "{{ .Name }}", "--cpus", 2],
    ["modifyvm", "{{ .Name }}", "--ioapic", "on"],
    ["modifyvm", "{{ .Name }}", "--pae", "off"],
    ["modifyvm", "{{ .Name }}", "--clipboard-mode", "bidirectional"],
    ["modifyvm", "{{ .Name }}", "--draganddrop", "bidirectional"],
    ["modifyvm", "{{ .Name }}", "--vrde", "off"],
    ["modifyvm", "{{ .Name }}", "--vrdeport", "default"],
    ["modifyvm", "{{ .Name }}", "--vrdeaddress", ""],
    ["modifyvm", "{{ .Name }}", "--nic1", "nat"],
    ["natnetwork", "modify", "--netname", "k8scluster", "--enable", "--dhcp", "off"],
    ["modifyvm", "{{ .Name }}", "--nic2", "natnetwork", "--nat-network2", "k8scluster"]
  ]
}

source "virtualbox-ovf" "k8s-basic_conf" {
  source_path      = "images/base/base-img.ovf"
  communicator     = "ssh"
  ssh_username     = "${var.os_user}"
  ssh_password     = "${var.os_user}"
  ssh_timeout      = "5m"
  shutdown_command = "sudo systemctl poweroff"

  output_directory = "images/k8s-basic"
  output_filename  = "k8s-basic"
}

source "virtualbox-ovf" "k8s-master_conf" {
  source_path      = "images/k8s-basic/k8s-basic.ovf"
  communicator     = "ssh"
  ssh_username     = "${var.os_user}"
  ssh_password     = "${var.os_user}"
  ssh_timeout      = "5m"
  shutdown_command = "sudo systemctl poweroff"

  output_directory = "images/k8s-control-plane"
  output_filename  = "k8s-control-plane"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--memory", "${var.mem_size-control-plane}"],
    ["modifyvm", "{{ .Name }}", "--cpus", "${var.num_of_cpus-control-plane}"],
    ["modifyvm", "{{ .Name }}", "--nic3", "hostonly", "--hostonlyadapter3", "${var.nodeport_hostdevice_name}"],
    ["sharedfolder", "add", "{{ .Name }}", "--name", "vm-build-share", "-hostpath", "${var.shared_folder_hostsystem_path}"]
  ]
}

source "virtualbox-ovf" "k8s-worker_conf" {
  source_path      = "images/k8s-basic/k8s-basic.ovf"
  communicator     = "ssh"
  ssh_username     = "${var.os_user}"
  ssh_password     = "${var.os_user}"
  ssh_timeout      = "5m"
  shutdown_command = "sudo systemctl poweroff"

  output_directory = "images/worker/${var.hostname-worker}"
  output_filename  = "${var.hostname-worker}"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--memory", "${var.mem_size-worker}"],
    ["modifyvm", "{{ .Name }}", "--cpus", "${var.num_of_cpus-worker}"],
    ["modifyvm", "{{ .Name }}", "--nic3", "hostonly", "--hostonlyadapter3", "${var.nodeport_hostdevice_name}"],
    ["sharedfolder", "add", "{{ .Name }}", "--name", "vm-build-share", "-hostpath", "${var.shared_folder_hostsystem_path}"]
  ]
}