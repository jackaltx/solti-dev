#! /bin/bash

VMID=7000
STORAGE=local-lvm

set -x
rm -f Rocky-9-GenericCloud.latest.x86_64.qcow2 
wget -q https://dl.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2 
qemu-img resize Rocky-9-GenericCloud.latest.x86_64.qcow2 8G
sudo qm destroy $VMID
sudo qm create $VMID --name "rocky9-template" --ostype l26 \
    --memory 4096 --balloon 1 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --cores 4 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1
sudo qm importdisk $VMID Rocky-9-GenericCloud.latest.x86_64.qcow2 $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --scsi1 $STORAGE:cloudinit
sudo qm set $VMID --tags rocky-template,rocky9,cloudinit
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm template $VMID
