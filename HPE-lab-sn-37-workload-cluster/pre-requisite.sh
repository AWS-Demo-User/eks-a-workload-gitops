#!/bin/bash


# SSH into the EC2 instance
ssh -i /home/telcoadmin/eksa-clusters/eksa-gitops/eksa-gitops-mgmt-multinode/eks-a-id_rsa ec2-user@10.45.10.81 << "EOF"
sudo su

# Set the HOME environment variable
export HOME=/home/ec2-user
export DT_DEMO="$HOME/dt-demo"

# Update package lists
sudo apt-get update
# Install sshpass
sudo apt-get install -y sshpass

#Copy file from the remote machine
mkdir -p "$DT_DEMO"
cd "$DT_DEMO"
sshpass -p 'HP1nvent' scp -r telcoadmin@10.45.10.30:/home/telcoadmin/yan/pre-requisite/* .

#import the RAN workload images
echo "Import RAN Workload Images"
cd "$DT_DEMO/images"
sudo ctr -n k8s.io image import bbdev_4_0_7_1.tar
sudo ctr -n k8s.io image import cu_4_0_3.tar
sudo ctr -n k8s.io image import du_4_0_3.tar
sudo ctr -n k8s.io image import flexran-l1_23_03.tar
sudo ctr -n k8s.io image import linuxptp-phc2sys_4_0_7.tar
sudo ctr -n k8s.io image import linuxptp-ptp4l_4_0_7.tar 

#copy the grub file
echo "INFO: grub changes"
cd "$DT_DEMO"
sudo cp grub /etc/default/grub
update-grub

#Install tuned
# Update package index
echo "INFO: Installing tuned package"
sudo apt update
# Check if tuned is installed
if ! dpkg -l | grep -q "^ii\s*tuned\s"; then
    # Install tuned package and related utilities
    sudo apt install -y tuned tuned-utils tuned-utils-systemtap
    # Enable tuned service to start automatically on boot
    sudo systemctl enable tuned
    # Start tuned service
    sudo systemctl start tuned
else
    echo "tuned is already installed."
fi

#CPU isolcation using tuned
cd "$DT_DEMO"
echo "INFO: setting tuned profile"
sudo cp realtime-variables.conf /etc/tuned/realtime-variables.conf

# Switch to the 'realtime' tuning profile
sudo tuned-adm profile realtime

#disable IP forwarding
echo "INFO: disable IP forwarding"
sudo sysctl -w net.ipv4.ip_forward=0
sudo systemctl stop firewalld

#Enaling coredump
echo "INFO: Enabling coredump"
sudo install -m 1777 -d 700 /var/local/core-dumps
#sudo echo /var/local/core-dumps/core.%e.%p.%t > /proc/sys/kernel/core_pattern
echo "/var/local/core-dumps/core.%e.%p.%t" | sudo tee /proc/sys/kernel/core_pattern
sudo kernel.core_pattern=/var/local/core-dumps/core.%e.%p.%t
sudo systemctl stop apport.service
sudo systemctl disable apport.service

#no firewalld service so no need to stop and disable it

#disable ufw
echo "INFO: disable ufw"
sudo systemctl stop ufw
sudo systemctl disable ufw

#enable Irqbalance
echo "INFO: enable Irqbalance"
sudo systemctl start irqbalance
sudo systemctl enable irqbalance

#install multus
sudo kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml

echo "INFO: cpu manager changes for kubelet"
cd "$DT_DEMO"
#copy the kubelet configuration file  (the kubelet with new configuration should restart again. Need to check the status)
sudo cp config.yaml /var/lib/kubelet/config.yaml
sudo rm -rf /var/lib/kubelet/cpu_manager_state
sudo systemctl restart kubelet

#copy dpdk package
cd "$DT_DEMO"
echo "INFO: setting dpdk packages"
sudo cp -r dpdk-kmods /opt/
sudo modprobe uio

#configure sriov resources
cd "$DT_DEMO"
echo "INFO: sriov resource changes"
sudo pip install termcolor
sudo pip install paramiko
sudo pip install scp
#./host-config/sriov-config.py -f host-config/sriov-config.yaml

#install helm
echo "INFO: Helm installation"
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo ./get_helm.sh

#install RT kernel
cd "$DT_DEMO"
pwd
echo "INFO: kernel installation"
tar -xvf 5.15.0-1031-realtime.tar.gz
cd 5.15.0-1031-realtime
sudo dpkg -i *.deb

sudo reboot
echo "Completed"
EOF  
