#!/bin/bash

IMGDIR=$HOME/Devel/images

BASE_IMG=focal-server-cloudimg-amd64.img

NAME=$(basename $PWD)

VMDIR=.vm

SSH_RSA=$(cat ~/.ssh/id_rsa.pub)

if [[ -d $VMDIR ]]; then
    echo "VM already exists, to re-create, run vm-destroy.sh first"
    exit 1
fi

mkdir -p $VMDIR

# Generate meta-data and user-data files
cat << EOF > $VMDIR/meta-data
instance-id: $NAME
local-hostname: $NAME
EOF

cat << EOF > $VMDIR/user-data
#cloud-config

users:
  - name: ubuntu
    ssh_authorized_keys:
      - $SSH_RSA
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
EOF

# Generate file system from base image
qemu-img create -b $IMGDIR/focal-server-cloudimg-amd64.img -f qcow2 -F qcow2 $VMDIR/$NAME.qcow2 10G

# Generate ISO image for cloudinit
genisoimage -output $VMDIR/cidata.iso -V cidata -r -J $VMDIR/user-data $VMDIR/meta-data

# Virt-install
virt-install \
    --name $NAME \
    --ram 1024 \
    --vcpus 1 \
    --import \
    --disk path=$VMDIR/$NAME.qcow2,format=qcow2 \
    --disk path=$VMDIR/cidata.iso,device=cdrom \
    --os-variant=ubuntu20.04 \
    --memorybacking access.mode=shared \
    --filesystem source=$PWD,target=code,accessmode=passthrough,driver.type=virtiofs \
    --noautoconsole
