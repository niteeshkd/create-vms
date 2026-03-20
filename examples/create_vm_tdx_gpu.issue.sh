#!/bin/bash

#-machine q35,hpet=off,kernel_irqchip=split,confidential-guest-support=tdx \
#-object '{"qom-type":"tdx-guest","id":"tdx","quote-generation-socket":{"type": "vsock", "cid":"2","port":"4050"}}' \

#-drive file=/var/home/core/create-vms/images/disk1.img,if=virtio \
#-drive file=/var/home/core/create-vms/images/nocloud1.iso,if=virtio,format=raw \
#-nic user,model=e1000,hostfwd=tcp::1001-:22 \

#-object iommufd,id=iommufd0 \
#-device pcie-root-port,id=pci.1,bus=pcie.0 \
#-device vfio-pci,host=0000:18:00.0,bus=pci.1,iommufd=iommufd0 \

/usr/libexec/qemu-kvm \
-name guest=vm1 -smp 4 \
-nographic -vga none \
-machine q35,accel=kvm,kernel_irqchip=split,confidential-guest-support=tdx \
-cpu host,pmu=off \
-object '{"qom-type":"tdx-guest","id":"tdx","quote-generation-socket":{"type": "vsock", "cid":"2","port":"4050"}}' \
-m 16G \
-device vfio-pci,host=0000:18:00.0 \
-bios /usr/share/edk2/ovmf/OVMF.inteltdx.fd \
-serial stdio \
-nodefaults \
-device virtio-net-pci,netdev=nic0 -netdev user,id=nic0,hostfwd=tcp::10022-:22 \
-drive file=/var/home/core/create-vms/images/disk1.img,if=none,id=virtio-disk0 \
-device virtio-blk-pci,drive=virtio-disk0
