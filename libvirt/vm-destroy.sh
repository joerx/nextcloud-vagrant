#!/bin/bash

NAME=$(basename $PWD)

VMDIR=.vm

if [[ ! -d $VMDIR ]]; then
    echo "VM does not exist, use vm-create.sh to create it."
    exit 1
fi

virsh destroy $NAME
virsh undefine $NAME

# some files inside the .vm dir will be owned by qemu, don't have a better idea right now
# maybe try to run the whole thing in qemu://session instead?
sudo rm -rf $VMDIR
