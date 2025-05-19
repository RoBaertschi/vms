#!/bin/sh
set -ex

# TODO: Download iso image

NAME=minimim-vm
ISO="alpine-virt-3.21.3-x86_64.iso"
OVMF="/nix/store/9rfp4fqcdjhgkbc7c3ml2m6h8i2l08r3-OVMF-202411-fd/FV"

if [ ! -d "${NAME}" ]; then
    mkdir -p ${NAME}
fi

if [ ! -f "${NAME}/${NAME}" ]; then
    qemu-img create -f qcow2 ${NAME}/${NAME}.qcow2 20G
fi

if [ ! -f "${NAME}/OVMF_VARS.fd" ]; then
    cp ${OVMF}/OVMF_VARS.fd ${NAME}/OVMF_VARS.fd
    chmod 755 ${NAME}/OVMF_VARS.fd
fi

# 1 chardev id
# 2 chardev name
# 3 device
# 4 device id
spicevmc() {
    echo -n -chardev spicevmc,id=${1},name=${2} -device ${3},chardev=${1},id=${4}
}

REDIRS=""
for redir in 1 2 3; do
    REDIRS="$REDIRS $(spicevmc "usbredirchardev${redir}" "usbredir" "usb-redir" "usbredirdev${redir}")"
done

qemu-system-x86_64 \
    -name ${NAME},process=${NAME} \
    -machine q35,smm=off,vmport=off,accel=kvm \
    -global kvm-pit.lost_tick_policy=discard \
    -cpu host,topoext \
    -smp cores=4,threads=2,sockets=1 \
    -m 8G \
    -device virtio-balloon \
    -rtc base=utc,clock=host \
    -vga none \
    -device virtio-vga-gl,xres=1280,yres=800 \
    -display sdl,gl=on \
    -device virtio-rng-pci,rng=rng0 \
    -object rng-random,id=rng0,filename=/dev/urandom \
    -device qemu-xhci,id=spicepass \
    $REDIRS \
    -device pci-ohci,id=smartpass \
    -device usb-ccid \
    -chardev spicevmc,id=ccid,name=smartcard -device ccid-card-passthru,chardev=ccid \
    -device usb-ehci,id=input \
    -device usb-kbd,bus=input.0 \
    -k de-ch \
    -device usb-tablet,bus=input.0 \
    -audiodev alsa,id=audio0 \
    -device intel-hda \
    -device hda-micro,audiodev=audio0 \
    -device virtio-net,netdev=nic \
    -netdev user,hostname=${NAME},hostfwd=tcp::22220-:22,smb=$HOME,id=nic \
    -global driver=cfi.pflash01,property=secure,value=on \
    -drive if=pflash,format=raw,unit=0,file=${OVMF}/OVMF_CODE.fd,readonly=on \
    -drive if=pflash,format=raw,unit=1,file=${NAME}/OVMF_VARS.fd \
    -drive media=cdrom,index=0,file=${ISO} \
    -device virtio-blk-pci,drive=SystemDisk \
    -drive id=SystemDisk,if=none,format=qcow2,file=${NAME}/${NAME}.qcow2 \
    -fsdev local,id=fsdev0,path=/home/robin,security_model=mapped-xattr \
    -device virtio-9p-pci,fsdev=fsdev0,mount_tag=Public-robin \
    -monitor unix:${NAME}/${NAME}-montior.socket,server,nowait \
    -serial unix:${NAME}/${NAME}-serial.socket,server,nowait

cat <<EOF

Quickemu 4.9.7 using /nix/store/h5g7vqw74zx9wj3s9kpm0vr8ybjkl5v2-qemu-9.2.3/bin/qemu-system-x86_64 v9.2.3
 - Host:     NixOS 25.11 (Xantusia) running Linux 6.12.21 deez-nix
 - CPU:      AMD Ryzen 7 5800X 8-Core Processor
 - CPU VM:   host, 1 Socket(s), 4 Core(s), 2 Thread(s)
 - RAM VM:   8G RAM
 - BOOT:     EFI (Linux), OVMF (/nix/store/9rfp4fqcdjhgkbc7c3ml2m6h8i2l08r3-OVMF-202411-fd/FV/OVMF_CODE.fd), SecureBoot (off).
 - Disk:     test2-alpine/disk.qcow2 (16G)
             Just created, booting from alpine-v3.21/alpine-virt-3.21.3-x86_64.iso
 - Boot ISO: alpine-v3.21/alpine-virt-3.21.3-x86_64.iso
 - Display:  SDL, virtio-vga-gl, GL (on), VirGL (on) @ (1280 x 800)
 - Sound:    intel-hda (hda-micro)
 - ssh:      On host:  ssh user@localhost -p 22220
 - WebDAV:   On guest: dav://localhost:9843/
 - 9P:       On guest: sudo mount -t 9p -o trans=virtio,version=9p2000.L,msize=104857600 Public-robin ~/robin
 - smbd:     On guest: smb://10.0.2.4/qemu
 - Network:  User (virtio-net)
 - Monitor:  On host:  socat -,echo=0,icanon=0 unix-connect:test2-alpine/test2-alpine-monitor.socket
 - Serial:   On host:  socat -,echo=0,icanon=0 unix-connect:test2-alpine/test2-alpine-serial.socket
EOF
