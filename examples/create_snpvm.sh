#!/bin/bash
# Qemu branch upmv10b-snpv3-wip
#/home/niteesh/github/AMDSEV_sev-snp-devel/qemu/build/qemu-system-x86_64 \

# Qemu branch snp_latest
/home/niteesh/github/AMDSEV_sev-snp-devel/snp-release-2023-03-22/usr/local/bin/qemu-system-x86_64 \
	-name guest=vm1 -smp 4 -accel kvm -nographic -vga none -cpu EPYC-Milan-v2  -m 4G \
       	-device virtio-scsi-pci,id=scsi,disable-legacy=on,iommu_platform=true \
	-drive file=/home/niteesh/sevtests/images/disk1.img,if=none,id=disk0 -device scsi-hd,drive=disk0 \
	-drive file=/home/niteesh/sevtests/images/nocloud1.iso,if=none,id=disk1,format=raw -device scsi-hd,drive=disk1 \
	-object memory-backend-memfd-private,id=ram1,size=4G,share=true \
	-object sev-snp-guest,id=sev0,cbitpos=51,reduced-phys-bits=1 \
        -machine q35,confidential-guest-support=sev0,memory-backend=ram1,kvm-type=protected \
	-drive if=pflash,format=raw,unit=0,file=/home/niteesh/github/AMDSEV_sev-snp-devel/ovmf/Build/OvmfX64/DEBUG_GCC5/FV/OVMF.fd,readonly=on \
	-kernel /boot/vmlinuz-6.1.0-rc4-snp-host-db73108c4fd6 \
	-initrd /boot/initrd.img-6.1.0-rc4-snp-host-db73108c4fd6 \
	-append "root=/dev/sda1 console=ttyS0"
