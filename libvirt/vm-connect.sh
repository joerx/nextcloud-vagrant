#!/bin/bash

NAME=$(basename $PWD)

IP=$(virsh domifaddr $NAME | grep ipv4 | tr -s ' ' | cut -d' ' -f5 | sed 's/\/[0-9]*$//')

exec ssh ubuntu@$IP
