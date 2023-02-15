param (
    [Parameter(Mandatory=$true)] [string] $target,
    [Parameter(Mandatory=$false)] [switch] $only = $false
)

$buildParams = Get-Content .\build_params.json -Raw | ConvertFrom-Json 

#Input the full path of you VBoxManage.exe executable. Leave it an empty string if you want the script to search for it
$vboxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$vboxControlNodeOVF = "images/k8s-control-plane/k8s-control-plane.ovf"

function execute_build {
    param ( 
        [Parameter(Mandatory = $true)] [string] $t,
        [Parameter(Mandatory = $true)] [string] $args
    )
    Start-Process -FilePath "packer.exe" -ArgumentList "build -force -only=`"$($target_mapping.$t)`" $args ." -NoNewWindow -Wait
    return $?
}

function build_linux_base {
    $p = `
        "-var=iso_url="+$buildParams.iso.url +`
        " -var=iso_checksum="+$buildParams.iso.checksum +`
        " -var=hdd_size="+$buildParams.hdd_size +`
        " -var=country_code="+$buildParams.country_code +`
        " -var=zoneinfo="+$buildParams.zoneinfo +`
        " -var=os_user="+$buildParams.username

    $r = execute_build -t "linux_base" -args $p
    return $r
}

function build_k8s_base {
    $p = "-var=os_user="+$buildParams.username
    $r = execute_build -t "k8s_base" -args $p
    return $r
}

function build_master {
    $p = `
        "-var=os_user="+$buildParams.username +`
        " -var=num_of_cpus-control-plane="+$buildParams.control_node.num_of_cpus +`
        " -var=mem_size-control-plane="+$buildParams.control_node.mem_size +`
        " -var=nodeport_hostdevice_name=`""+$buildParams.network.nodeport_hostdevice_name + "`"" +`
        " -var=shared_folder_hostsystem_path=`""+$buildParams.shared_folder + "`"" +`
        " -var=hostname-control-plane="+$buildParams.control_node.hostname +`
        " -var=pod_network_cidr="+$buildParams.network.pod_network_cidr +`
        " -var=node_network_cidr="+$buildParams.network.node_network_cidr +`
        " -var=node_network_ip_master="+$buildParams.control_node.node_network_ip +`
        " -var=node_network_iface_name="+$buildParams.network.node_network_iface_name +`
        " -var=nodeport_iface_name="+$buildParams.network.nodeport_iface_name
    $r = execute_build -t "master" -args $p
    return $r
}

function build_worker {
    param (
        [Parameter(Mandatory=$true)] $worker
    )
    $p = `
        "-var=os_user="+$buildParams.username +`
        " -var=num_of_cpus-worker="+$worker.num_of_cpus +`
        " -var=mem_size-worker="+$worker.mem_size +`
        " -var=nodeport_hostdevice_name=`""+$buildParams.network.nodeport_hostdevice_name + "`"" +`
        " -var=shared_folder_hostsystem_path=`""+$buildParams.shared_folder + "`"" +`
        " -var=hostname-worker="+$worker.hostname +`
        " -var=hostname-control-plane="+$buildParams.control_node.hostname +`
        " -var=node_network_ip_master="+$buildParams.control_node.node_network_ip +`
        " -var=node_network_ip_worker="+$worker.node_network_ip +`
        " -var=node_network_iface_name="+$buildParams.network.node_network_iface_name +`
        " -var=nodeport_iface_name="+$buildParams.network.nodeport_iface_name
    $r = execute_build -t "worker" -args $p
    return $r
}

function buildWorkerAndAddToCluster {
    $vmName = "k8s-control-$(Get-Random)"

    Write-Host("Importing K8S Control-Node from OVF: ", $vboxControlNodeOVF) -ForegroundColor Green
    $pret = Start-Process -FilePath $vboxManage -ArgumentList "import $($vboxControlNodeOVF) --vsys 0 --vmname $($vmName)" -NoNewWindow -Wait -PassThru
    if($pret.ExitCode -ne 0) {
        Write-Host("Importing", $vboxControlNodeOVF, "image failed") -ForegroundColor Red
        exit
    }

    Write-Host("Adding PortForward-Rule for SSH") -ForegroundColor Green
    $pret = Start-Process -FilePath $vboxManage -ArgumentList "modifyvm `"$($vmName)`" --natpf1 `"guestssh,tcp,,22222,,22`"" -NoNewWindow -Wait -PassThru
    if($pret.ExitCode -ne 0) {
        Write-Host("Setting", $vboxControlNodeOVF, "SSH port forwarding failed") -ForegroundColor Red
        exit
    }

    Write-Host("Starting worker node in headless mode") -ForegroundColor Green
    $pret = Start-Process -FilePath $vboxManage -ArgumentList "startvm `"$($vmName)`" --type headless" -NoNewWindow -Wait -PassThru
    if($pret.ExitCode -ne 0) {
        Write-Host("Starting worker vm", $vmName, "failed") -ForegroundColor Red
        exit
    }
    #Give the VM time to start
    Write-Host("Waiting 30 seconds to give the control-node a chance to boot and fire up sshd") -ForegroundColor Green
    Start-Sleep -Seconds 30
    ssh -o StrictHostKeyChecking=no -l $buildParams.username -p22222 -i id_rsa 127.0.0.1 timeout 2m kubectl wait --for=condition=ready node --all -A --timeout -1s
    if($LASTEXITCODE -ne 0) {
        Write-Host("Worker node was not ready in time") -ForegroundColor Red
        Write-Host("Stopping vm: ", $vmName) -ForegroundColor Green
        $pret = Start-Process -FilePath $vboxManage -ArgumentList "controlvm `"$($vmName)`"", "acpipowerbutton" -NoNewWindow -Wait -PassThru
        if($pret.ExitCode -ne 0) {
            Write-Host("Stopping vm", $vmName, "failed. Now you have to cleanup by yourself. Good luck ;-)") -ForegroundColor Red
            exit
        }
        exit
    }

    foreach($worker in $buildParams.worker_nodes) {
        Write-Host("Building worker: ", $worker.hostname) -ForegroundColor Green
        if(! (build_worker $worker)) {
            Write-Host("Building worker ", $worker.hostname, "failed") -ForegroundColor Red
        }
    }
    Write-Host("Stopping vm: ", $vmName) -ForegroundColor Green
    ssh -o StrictHostKeyChecking=no -l $buildParams.username -p22222 -i id_rsa 127.0.0.1 sudo systemctl poweroff
    $shutdown = $false
    for($i = 0; $i -lt 5; $i++) {
        Write-Host("Waiting 20 seconds to give the control-node a chance to poweroff correctly") -ForegroundColor Green
        Start-Sleep -Seconds 20

        Write-Host("Checking if vm", $vmName, "is shutdown") -ForegroundColor Green
        $pret = & $vboxManage list runningvms | Out-String | Select-String -Pattern $vmName
        if(!$pret) {
            $shutdown = $true
            break
        }
    }
    if(!$shutdown) {
        Write-Host("VM", $vmName, "could not be stopped correctly. Now you are on your own. Good luck ;)")
        exit
    }

    Write-Host("Deleting PortForward-Rule for SSH") -ForegroundColor Green
    $pret = Start-Process -FilePath $vboxManage -ArgumentList "modifyvm `"$($vmName)`" --natpf1 delete guestssh" -NoNewWindow -Wait -PassThru
    if($pret.ExitCode -ne 0) {
        Write-Host("Removing", $vboxControlNodeOVF, "SSH port forwarding failed") -ForegroundColor Red
    }
    
    Move-Item -Path $vboxControlNodeOVF -Destination $vboxControlNodeOVF".bak" -Force
    $vmdk = $vboxControlNodeOVF.Substring(0, $vboxControlNodeOVF.Length-4)+"-disk001.vmdk"
    Move-Item -Path $vmdk -Destination $vmdk".bak" -Force
    Write-Host("Exporting VM") -ForegroundColor Green
    & $vboxManage export $vmName --output=$vboxControlNodeOVF
    if($LASTEXITCODE -ne 0) {
        Write-Host("VM", $vmName, "could not be exported to: ", $vboxControlNodeOVF, "Now you are on your own. Good luck ;)") -ForegroundColor Red
        exit
    }

    & $vboxManage unregistervm --delete  "$vmName"
    if($LASTEXITCODE -ne 0) {
        Write-Host("VM", $vmName, "could not be unregistered. Try to delete the VM manually using your VBox-UI oder Vboxmanage unregistervm command") -ForegroundColor Red
        exit
    }
}

$target_mapping = @{
    linux_base = 'build_basicvm.virtualbox-iso.basic_vm'
    k8s_base = 'build_k8s_basic_conf.virtualbox-ovf.k8s-basic_conf'
    master = 'build_k8s_master_conf.virtualbox-ovf.k8s-master_conf'
    worker = 'build_k8s_worker_conf.virtualbox-ovf.k8s-worker_conf'
}

if(!$vboxManage) {
    #Start searching for VBoxManage Executable
    $vboxManage = Get-ChildItem -Path "C:\" -Recurse -ErrorAction 'silentlycontinue'  | Where-Object {$_.Name -eq "VboxManage.exe"} |Select-Object -First 1 FullName
    $vboxManage = $vboxManage.FullName
}

switch($target) {
    'all' {
        if(!$only) {
            if(! (build_linux_base)) {
                Write-Host("Building dependent linux base image failed") -ForegroundColor Red
                exit
            }
            if(! (build_k8s_base)) {
                Write-Host("Building dependent k8s base image failed") -ForegroundColor Red
                exit
            }
            if(! (build_master)) {
                Write-Host("Building dependent k8s master image failed") -ForegroundColor Red
                exit
            }
        }
        buildWorkerAndAddToCluster
    }
    'linux_base' {
        build_linux_base
    }
    'k8s_base' {
        if(!$only) {
            if(! (build_linux_base)) {
                Write-Host("Building dependent linux base image failed") -ForegroundColor Red
                exit
            }
        }
        build_k8s_base
    }
    'worker' {
        if(!$only) {
            if(! (build_linux_base)) {
                Write-Host("Building dependent linux base image failed") -ForegroundColor Red
                exit
            }
            if(! (build_k8s_base)) {
                Write-Host("Building dependent k8s base image failed") -ForegroundColor Red
                exit
            }
            if(! (build_master)) {
                Write-Host("Building dependent k8s master image failed") -ForegroundColor Red
                exit
            }
        }
        buildWorkerAndAddToCluster
    }
    'master' {
        if(!$only) {
            if(! (build_linux_base)) {
                Write-Host("Building dependent linux base image failed") -ForegroundColor Red
                exit
            }
            if(! (build_k8s_base)) {
                Write-Host("Building dependent k8s base image failed") -ForegroundColor Red
                exit
            }
        }
        build_master
    }
    default {
        $script_name = $MyInvocation.InvocationName
        Write-Host("Usage: $script_name -target TARGET [-only]")
        Write-Host("")
        Write-Host("Possible targets:")
        Write-Host("    all - Builds everything")
        Write-Host("    linux_base - Builds an VirtualBox image with an basic installed Arch-Linux")
        Write-Host("    k8s_base - Takes the image build with target vbox_base and does the kubernetes basic configuration")
        Write-Host("    master - Takes kubernetes base image and configures it as the kubernetes control plane node")
        Write-Host("    worker - Takes kubernetes base image, configures it as a worker node and populates that worker into the cluster")
        Write-Host("")
        Write-Host("-only is an optional parameter which tells the build process to NOT build all up until the given target.")
        Write-Host("To understand that you need to know the dependencies of the builds:")
        Write-Host("    First build: The basic build is target ""vbox_base"".")
        Write-Host("    Second build: The target ""base"" uses the image produces by target ""vbox_base"" and produces another one")
        Write-Host("    Third build(master): The target ""master"" uses the image produced by target ""base"" and produces a running image with an full kubernetes control plane mode")
        Write-Host("    Third build(worker): The target ""worker"" uses the image produced by target ""base"" and produces a running image with an full kubernetes worker node which is clustered with the control plane node")
        Write-Host("This means for example that if you specify target ""master"" without the ""-only"" option, the complete build process will start. First ""linux_base"" will be created, then ""k8s_base"" and then ""master""")
        Write-Host("If you just want to create the ""master"" image without build all dependend images input the ""-only"" option. This assumes that all previous and needed build are already there")
        Write-Host("DONT FORGET TO CONFIGURE build.params.json TO YOUR NEED!") -ForegroundColor Red
        Write-Host("EVERY IMAGE ALREADY CREATED WILL BE DELETED WHEN EXECUTING!") -ForegroundColor Red
    }
}