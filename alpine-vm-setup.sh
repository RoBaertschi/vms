#!/bin/sh
set -ex

KERNEL=$(uname -s)
case "$KERNEL" in
    Darwin)
        export PATH="$HOME/quickemu:$PATH"
        ;;
    *)
        ;;
esac

quickget alpine v3.21

cat > minimim-vm.conf <<EOF
#!$(which quickemu)
guest_os="linux"
disk_img="minimim-vm/disk.qcow2"
iso="alpine-v3.21/alpine-virt-3.21.3-x86_64.iso"
EOF

mkdir -p minimim-vm

quickemu --vm minimim-vm.conf --extra_args "-virtfs local,path=$(pwd),mount_tag=shared,security_model=mapped-xattr"
