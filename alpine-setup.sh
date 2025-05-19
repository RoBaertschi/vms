#!/bin/sh

set -ex

rcser() {
    for service in "$@"; do
        rc-update add $service
        rc-service $service start
    done
}

setup-keymap ch ch
setup-hostname localhost
setup-interfaces -a -r eth0
rc-service networking start
setup-timezone -z Europe/Zurich
rc-service hostname restart
rc-update add networking boot
rc-update add seedrng boot
rc-update add acpid
rc-update add crond
openrc boot
openrc default

/etc/apk/repositories <<EOF
/media/sr0/apks
http://dl-cdn.alpinelinux.org/alpine/edge/main
http://dl-cdn.alpinelinux.org/alpine/edge/community
http://dl-cdn.alpinelinux.org/alpine/edge/testing
EOF

apk update

# setup-apkrepos -f -c
setup-user -a -f robin -g audio,input,video,netdev robin
echo "Please create a password for user \"robin\""
passwd robin
echo "Please create a password for user \"root\""
passwd root

echo "Setup openssh"
setup-sshd -c openssh

echo "Setup ntp"
setup-ntp chronyd

echo "Setting up spice"
apk add spice-vdagent spice-webdavd
rcser spice-vdagentd spice-webdavd

echo "Setting up elogind with PAM"
apk add elogind polkit-elogind linux-pam util-linux-login
rcser polkit elogind

echo "udev setup"
apk add eudev udev-init-scripts udev-init-scripts-openrc
for service in udev udev-trigger udev-settle; do
    rc-update add $service sysinit
done
rc-update add udev-postmount default
for service in udev udev-trigger udev-settle udev-postmount; do
    rc-service $service start
done

rcser cgroups dbus

export USE_EFI=1
echo "Creating disk, user input required."
setup-disk -m sys
