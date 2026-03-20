#!/bin/bash

#-nic user,model=e1000,hostfwd=tcp::1001-:22 \

#Different disks
#-drive file=/var/home/core/create-vms/images/disk1_ub2404.img,if=virtio \
#-drive file=/var/home/core/create-vms/images/disk1_rh10.img,if=virtio \

/usr/libexec/qemu-kvm \
-name guest=vm1 -smp 4 \
-nographic -vga none \
-machine q35,accel=kvm,kernel_irqchip=split,confidential-guest-support=tdx \
-cpu host,pmu=off \
-object '{"qom-type":"tdx-guest","id":"tdx","quote-generation-socket":{"type": "vsock", "cid":"2","port":"4050"}}' \
-m 16G \
-bios /usr/share/edk2/ovmf/OVMF.inteltdx.fd \
-serial stdio \
-nodefaults \
-device virtio-net-pci,netdev=nic0 -netdev user,id=nic0,hostfwd=tcp::10022-:22 \
-drive file=/var/home/core/create-vms/images/disk1_ub2404.img,if=virtio \
-drive file=/var/home/core/create-vms/images/nocloud1.iso,if=virtio,format=raw
