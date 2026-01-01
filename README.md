# Tools to create VMs with various configurations
## Steps:
1. Clone the repo and cd into create-vms/
2. Create images/tmp directory ( `mkdir -p images/tmp` )
3. Install genisoimage if not installed
4. Source `test.env` file (i.e. `source test.env` ).
5. Run `create_disk_cloudinit.sh` which creates disk and nocloud.iso images.
```
./create_disk_cloudinit.sh <vm_num> <src_img> [<size_GB>]
where
 vm_num   = Seqeunce number of the VM
 src_img  = Location of the .img file with prefix URL or PATH
 size_GB  = Size of the disk in GB (default=10GB)
Examples:
./create_disk_cloudinit.sh 1 URL=https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
./create_disk_cloudinit.sh 2 URL=https://download.fedoraproject.org/pub/fedora/linux/releases/35/Cloud/x86_64/images/Fedora-Cloud-Base-35-1.2.x86_64.qcow2 20
./create_disk_cloudinit.sh 3 PATH=/home/niteesh/sevtest/images/focal-server-cloudimg-amd64.img 20

```
7. Update `test.env` for QEMU path [and optionally other variables] and resource `test.env`.
8. Create VM by running `create_vm.sh`.
```
./create_vm.sh <vm_num> [WITH]  [extra_qemu_options]
where
 vm_num              = Sequence number for the VM
 WITH                = One or more of the folloiwng keys seperated by "_"
                        MEMFD, PVTMEM, TMPSHM, DEVDAXSHM, FSDAXSHM, MEMFILE,
                        TAPNET, USERNET, GPU, QGA, QMP, MON,
                        UPM, SEV, SNP, OVMF, OVMFS, DEBUG, TPM, DIRECT
 extra_qemu_optionss = Extra qemu options e.g. "-S", "-incmoing defer" "-m 16G"
 Examples: ./create_vm.sh 1
           ./create_vm.sh 1 SNP_OVMF_DEBUG_TAPNET_DIRECT
           ./create_vm.sh 1 UPM_SNP_PVTMEM_OVMF_DEBUG_TAPNET_DIRECT
           ./create_vm.sh 1 UPM_SNP_OVMF_DEBUG
           ./create_vm.sh 1 SEV_OVMF_MON_QMP_DEBUG
           ./create_vm.sh 5 USERNET
           ./create_vm.sh 5 TAPNET
           ./create_vm.sh 5 TPM_OVMFS_USERNET
           ./create_vm.sh 5 MEMFD_TAPNET
           ./create_vm.sh 5 TMPSHM_TAPNET
           ./create_vm.sh 3 DEVDAXSHM_TAPNET_GPU_QGA
           ./create_vm.sh 5 FSDAXSHM_TAPNET
           ./create_vm.sh 5 FSDAXSHM_TAPNET "-S"
           ./create_vm.sh 5 FSDAXSHM_TAPNET_QGA "-m 16G"
           ./create_vm.sh 5 FSDAXSHM_TAPNET_QGA "-incoming defer"
 Note: Sudo user can use 'sudo -E' to execute the script.
```
