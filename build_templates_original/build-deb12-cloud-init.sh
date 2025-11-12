#! /bin/bash

VMID=9001
VNAME=debian-12-template-$VMID
STORAGE=local-lvm

set -x

# rm -f debian-12-generic-amd64.qcow2
# wget -q https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
# qemu-img resize debian-12-generic-amd64.qcow2 8G

#
qm destroy $VMID
#
qm create $VMID --name $VNAME --ostype l26 \
  --memory 4096 --balloon 2048 \
  --agent 1 \
  --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
  --cpu host --cores 4 --numa 1 \
  --vga serial0 --serial0 socket  \
  --net0 virtio,bridge=vmbr0,mtu=1

#
qm importdisk $VMID debian-12-generic-amd64.qcow2 $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
qm set $VMID --boot order=virtio0
qm set $VMID --scsi1 $STORAGE:cloudinit


#
#cat << EOF | sudo tee /var/lib/vz/snippets/debian-12.yaml
##cloud-config
#runcmd:
#    - apt-get update
#    - apt-get install -y qemu-guest-agent
#    - reboot
## Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
#EOF
#

qm set $VMID --cipassword '$5$y2OS9eL0$bWzSRl5yM/r2r5Gj4DyHAgE89Te4NDlBjilRZ8kszd9'
#qm set $VMID --sshkeys './ssh-access.pub'
qm set $VMID --tags debian-template,debian-12,cloudinit
qm set $VMID --ciuser $USER
qm set $VMID --sshkeys ~/.ssh/authorized_keys
qm set $VMID --ipconfig0 ip=dhcp
qm template $VMID
