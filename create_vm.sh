#!/bin/bash
#DEBUG_PRINT="Y" #If exported as a command line, use '-E' option with sudo.

#main

if [[ $# -lt 1 ]]; then
    echo "$0 <vm_num> [WITH]  [extra_qemu_options]"
    echo "where"
    echo " vm_num              = Sequence number for the VM"
    echo " WITH                = One or more of the folloiwng keys seperated by \"_\""
    echo "                        MEMFD, PVTMEM, TMPSHM, DEVDAXSHM, FSDAXSHM, MEMFILE,"
    echo "                        TAPNET, USERNET, GPU, QGA, QMP, MON,"
    echo "                       UPM, SEV, SNP, OVMF, OVMFS, DEBUG, TPM, DIRECT"
    echo " extra_qemu_optionss = Extra qemu options e.g. \"-S\", \"-incmoing defer\" \"-m 16G\""
    echo " Examples: $0 1"
    echo "           $0 1 SNP_OVMF_DEBUG_TAPNET_DIRECT"
    echo "           $0 1 UPM_SNP_PVTMEM_OVMF_DEBUG_TAPNET_DIRECT"
    echo "           $0 1 UPM_SNP_OVMF_DEBUG"
    echo "           $0 1 SEV_OVMF_MON_QMP_DEBUG"
    echo "           $0 5 USERNET"
    echo "           $0 5 TAPNET"
    echo "           $0 5 TPM_OVMFS_USERNET"
    echo "           $0 5 MEMFD_TAPNET"
    echo "           $0 5 TMPSHM_TAPNET"
    echo "           $0 3 DEVDAXSHM_TAPNET_GPU_QGA"
    echo "           $0 5 FSDAXSHM_TAPNET"
    echo "           $0 5 FSDAXSHM_TAPNET \"-S\""
    echo "           $0 5 FSDAXSHM_TAPNET_QGA \"-m 16G\""
    echo "           $0 5 FSDAXSHM_TAPNET_QGA \"-incoming defer\""
    echo " Note: Sudo user can use 'sudo -E' to execute the script."
    exit 1
fi
vm_num=$1

CREATE_VM_ENV=""
extraArgs=""
if [[ $# -gt 1 ]]; then
    echo $2 | grep -e MEMFD -e TMPSHM -e DEVDAXSHM -e FSDAXSHM -e MEMFILE -e TAPNET -e USERNET -e GPU -e QGA -e QMP -e MON -e SEV -e SNP -e OVMF -e DEBUG -e TPM -e DIRECT -e UPM -e PVTMEM >/dev/null
    if [[ $? -eq 0 ]]; then
        CREATE_VM_ENV=$2
        if [[ $3 != "" ]]; then
            extraArgs="$3"
        fi
    else
         extraArgs=$2
    fi
fi

#Some sanity checking
if [[ $UID -ne 0 ]]; then
    echo "It should be executed by root/sudo user."
    exit 1
fi
if [[ ! -d ${IMAGE_DIR} ]] ; then
    echo "The image directory ${IMAGE_DIR} does not exist!"
    exit 1
else
    mkdir ${TMP_DIR} 2>/dev/null
    chmod 777 ${TMP_DIR} 2>/dev/null
fi

vm_name="vm${vm_num}"

#Paths for images and other files
diskImage=${IMAGE_DIR}/disk${vm_num}.img
noCloudImage=${IMAGE_DIR}/nocloud${vm_num}.iso

#ovmfCodeFile=${IMAGE_DIR}/OVMF${vm_num}.fd
ovmfVarsFile=${IMAGE_DIR}/OVMF_VARS${vm_num}.fd

monSockFile="${TMP_DIR}/monsock${vm_num}"
qgaSockFile="${TMP_DIR}/qgasock${vm_num}"
qmpSockFile="${TMP_DIR}/qmpsock${vm_num}"
tpmSockFile="${TMP_DIR}/tpmsock${vm_num}"
ovmfDebugLog="${TMP_DIR}/debug${vm_num}.log"
createVmLogFile="${TMP_DIR}/create_vm.log"
createVmCmdFile="${TMP_DIR}/create_vm${vm_num}.sh"

#QEMU Patch with memfd-alloc option
PATCH=0
$QEMU --help | grep -w "memfd\-alloc=on" >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    PATCH=3
else
    $QEMU --help | grep -w "\-memfd\-alloc" >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        PATCH=2
    fi
fi

#Basic options
memSize=4G
NCPUS=4
options_0="-name guest=${vm_name} -smp ${NCPUS} -accel kvm -nographic -vga none"

# https://lore.kernel.org/kvm/20230220183847.59159-1-michael.roth@amd.com/
if [[ $CREATE_VM_ENV =~ "SEV" || $CREATE_VM_ENV =~ "SNP" ]]; then
    if [[ $CREATE_VM_ENV =~ "SNP" ]]; then
        CPU="EPYC-v4"
    else
        CPU="EPYC"
    fi
    MACH="q35"
    options_fixed="${options_0} -machine ${MACH} -cpu ${CPU}"
else
    MACH="pc"
    options_fixed="${options_0} -machine ${MACH}"
fi

#Extra arguments 
if [[ $extraArgs =~ "-m" ]]; then
  memSize=`echo ${extraArgs} | awk -F"-m" '{print $2}' | awk '{print $1}'`
  options_extra="${extraArgs}"
else
  options_extra="${extraArgs} -m $memSize"
fi

[[ $DEBUG_PRINT ]] && echo "options_extra:$options_extra"
options="${options_fixed} ${options_extra}"

#QEMU options for DEVDAXSHM / FSDAXSHM / TMPSHM / MEMFD memory
if [[ $CREATE_VM_ENV =~ "DEVDAXSHM" ]]; then
    memId="mem${vm_num}"
    memFile="${DEVDAX_FILE}"
    #options_mem="-object memory-backend-file,id=${memId},share=on,mem-path=${memFile},size=${memSize},align=2M -numa node,memdev=${memId}"
    options_mem="-object memory-backend-file,id=${memId},share=on,pmem=on,mem-path=${memFile},size=${memSize},align=2M -numa node,memdev=${memId}"
elif [[ $CREATE_VM_ENV =~ "FSDAXSHM" ]]; then
    memId="mem${vm_num}"
    memFile="${FSDAX_MNT}/dax${vm_num}"
    #options_mem="-object memory-backend-file,id=${memId},share=on,mem-path=${memFile},size=${memSize},align=2M -numa node,memdev=${memId}"
    options_mem="-object memory-backend-file,id=${memId},share=on,pmem=on,mem-path=${memFile},size=${memSize},align=2M -numa node,memdev=${memId}"
elif [[ $CREATE_VM_ENV =~ "MEMFILE" ]]; then
    memId="mem${vm_num}"
    memFile="${TMP_DIR}/memfile${vm_num}"
    options_mem="-object memory-backend-file,id=${memId},share=on,mem-path=${memFile},size=${memSize},align=2M -numa node,memdev=${memId}"
elif [[ $CREATE_VM_ENV =~ "TMPSHM" ]]; then
    memId="mem${vm_num}"
    memFile="${TMPFS_MNT}/memfile${vm_num}"
    options_mem="-object memory-backend-file,id=${memId},share=on,mem-path=${memFile},size=${memSize},align=2M -numa node,memdev=${memId}"
elif [[ $CREATE_VM_ENV =~ "PVTMEM" ]]; then
    if [[ $CREATE_VM_ENV =~ "UPM" ]]; then
        memId="mem${vm_num}"
        options_mem="-object memory-backend-memfd,id=${memId},share=true,size=${memSize},prealloc=false"
    else
	echo "Requires UPM"
	exit 1
    fi
elif [[ $CREATE_VM_ENV =~ "MEMFD" ]]; then
    if [[ $PATCH -eq 2 ]]; then
        options_mem="-memfd-alloc"
    elif [[ $PATCH -eq 3 ]]; then
        options_mac=$(echo ${options} | sed 's/-machine pc/-machine pc,memfd-alloc=on/g')
    else
        echo "memfd-alloc is not supported!"
	exit
    fi
fi
if [[ $CREATE_VM_ENV =~ "MEMFD" && $PATCH -eq 3 ]]; then
    [[ $DEBUG_PRINT ]] && echo "options_mac:${options_mac}"
    options="${options_mac}"
else
    [[ $DEBUG_PRINT ]] && echo "options_mem:${options_mem}"
    options="${options} ${options_mem}"
fi

#QEMU options for Disks
if [[ $CREATE_VM_ENV =~ "SEV" || $CREATE_VM_ENV =~ "SNP" ]]; then
    #Virtio SCSI emulation
    options_disks="-device virtio-scsi-pci,id=scsi,disable-legacy=on,iommu_platform=true -drive file=${diskImage},if=none,id=disk0 -device scsi-hd,drive=disk0 -drive file=${noCloudImage},if=none,id=disk1,format=raw -device scsi-hd,drive=disk1"
    #options_disks="-device virtio-scsi-pci,id=scsi,disable-legacy=on,iommu_platform=true -drive file=${diskImage},if=none,id=disk0 -device scsi-hd,drive=disk0"
else
    #Virtio-BLK drive
    options_disks="-drive file=${diskImage},if=virtio -drive file=${noCloudImage},if=virtio,format=raw"
fi
[[ $DEBUG_PRINT ]] && echo "options_disks:$options_disks"
options="${options} ${options_disks}"

#QEMU options for tap network
if [[ $CREATE_VM_ENV =~ "TAPNET" ]]; then
    netdevId="netdev${vm_num}"
    mac_addr=$(printf 'DE:AD:BE:EF:AD:%02X\n' ${vm_num})
    nicId="nic${vm_num}"
    if [[ $CREATE_VM_ENV =~ "SEV" || $CREATE_VM_ENV =~ "SNP" ]]; then
        options_tapnet="-netdev tap,id=${netdevId},br=virbr0,helper=/usr/lib/qemu/qemu-bridge-helper -device virtio-net-pci,netdev=${netdevId},id=${nicId},mac=${mac_addr},disable-legacy=on,iommu_platform=true,romfile="
    else
        options_tapnet="-netdev tap,id=${netdevId},br=virbr0,helper=/usr/lib/qemu/qemu-bridge-helper -device virtio-net-pci,netdev=${netdevId},id=${nicId},mac=${mac_addr}"
    fi
    [[ $DEBUG_PRINT ]] && echo "options_tapnet:${options_tapnet}"
    options="${options} ${options_tapnet}"

elif [[ $CREATE_VM_ENV =~ "USERNET" ]]; then
    netdevId="netdev${vm_num}"
    mac_addr=$(printf 'DE:AD:BE:EF:AD:%02X\n' ${vm_num})
    nicId="nic${vm_num}"
    sshPort=$((SSHPORT0 +vm_num))  # User on Host can access Guest VM by using 'ssh  -p ${sshPort} ${guestUser}@localhost'

    if [[ $CREATE_VM_ENV =~ "SEV" || $CREATE_VM_ENV =~ "SNP" ]]; then
        options_usernet="-netdev user,id=${netdevId},hostfwd=tcp::${sshPort}-:22 -device virtio-net,netdev=${netdevId},iommu_platform=true,romfile="
        #options_usernet="-netdev user,id=${netdevId},hostfwd=tcp::${sshPort}-:22 -device e1000,netdev=${netdevId},disable-legacy=on,iommu_platform=true,romfile="
        #options_usernet="-netdev user,id=${netdevId},net=192.168.100.0/24,dhcpstart=192.168.100.1 -device virtio-net-pci,netdev=${netdevId},id=${nicId},mac=${mac_addr},disable-legacy=on,iommu_platform=true,romfile="
    else
        options_usernet="-nic user,model=e1000,hostfwd=tcp::${sshPort}-:22"
        #options_usernet="-net user,hostfwd=tcp::${sshPort}-:22 -net nic,model=e1000"
        #options_usernet="-net user,hostfwd=tcp::${sshPort}-:22 -net nic,model=virtio"
    fi

    [[ $DEBUG_PRINT ]] && echo "options_usernet:${options_usernet}"
    options="${options} ${options_usernet}"
    
fi

#QEMU options for GPU passthrough
if [[ $CREATE_VM_ENV =~ "GPU" ]]; then
    if [[ $vm_num -ne 3 ]]; then
        echo "GPU is not available!"
        exit 1
    fi
    #options_gpu="-cpu host,kvm=off -device vfio-pci,host=${GPU_ADDR}"
    options_gpu="-cpu host -device vfio-pci,host=${GPU_ADDR}"
    [[ $DEBUG_PRINT ]] && echo "options_gpu:${options_gpu}"
    options="${options} ${options_gpu}"
fi

#QEMU options for qemu guest agent
if [[ $CREATE_VM_ENV =~ "QGA" ]]; then
    qgaId="qga${vm_num}"
    if [[ $PATCH -eq 2 ]]; then
        options_qga="-chardev socket,path=${qgaSockFile},server,nowait,id=${qgaId} -device virtio-serial -device virtserialport,chardev=${qgaId},name=org.qemu.guest_agent.0"
    else
        options_qga="-chardev socket,path=${qgaSockFile},server=on,wait=off,id=${qgaId} -device virtio-serial -device virtserialport,chardev=${qgaId},name=org.qemu.guest_agent.0"

    fi
    [[ $DEBUG_PRINT ]] && echo "options_qga:${options_qga}"
    options="${options} ${options_qga}"
fi

#QEMU options for monitor
if [[ $CREATE_VM_ENV =~ "MON" ]]; then
    if [[ $MONPORT0 ]] ; then
        monPort=$((MONPORT0 +vm_num))
        options_mon="-monitor telnet::${monPort},server,nowait" #accessed using telnet localhost ${monPort}
    else
        options_mon="-monitor unix:${monSockFile},server,nowait"
    fi
    [[ $DEBUG_PRINT ]] && echo "options_mon:${options_mon}"
    options="${options} ${options_mon}"
fi

#QEMU options for qmp socket 
if [[ $CREATE_VM_ENV =~ "QMP" ]]; then
    if [[ $QMPPORT0 ]] ; then
        qmpPort=$((QMPPORT0 +vm_num))
        options_qmp="-qmp tcp:localhost:${qmpPort},server,nowait"
    else
        options_qmp="-qmp unix:${qmpSockFile},server,nowait"
    fi
    [[ $DEBUG_PRINT ]] && echo "options_qmp:${options_qmp}"
    options="${options} ${options_qmp}"
fi

if [[ $CREATE_VM_ENV =~ "SEV" ]]; then
    CBITPOS=47
    CERT_FILE="${CERT_DIR}/godh.cert.base64.p${SEV_GUEST_POLICY}"
    SESSION_FILE="${CERT_DIR}/launch_blob.bin.base64.p${SEV_GUEST_POLICY}"

    if [[ $CREATE_VM_ENV =~ "UPM" ]]; then
       if [[ $CREATE_VM_ENV =~ "PVTMEM" ]]; then
	    #CBITPOS=51
            options_sev="-object sev-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1,policy=${SEV_GUEST_POLICY},dh-cert-file=${CERT_FILE},session-file=${SESSION_FILE} -machine confidential-guest-support=sev0,kvm-type=protected,memory-backend=${memId}"
       else
            echo "Requires PVTMEM"
	    exit 1
       fi
    else
        #options_sev="-object sev-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1,policy=${SEV_GUEST_POLICY},dh-cert-file=${CERT_FILE},session-file=${SESSION_FILE} -machine memory-encryption=sev0"
        options_sev="-object sev-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1,policy=${SEV_GUEST_POLICY},dh-cert-file=${CERT_FILE},session-file=${SESSION_FILE} -machine confidential-guest-support=sev0"
    fi

    [[ $DEBUG_PRINT ]] && echo "options_sev:${options_sev}"
    options="${options} ${options_sev}"

elif [[ $CREATE_VM_ENV =~ "SNP" ]]; then
    CBITPOS=51
    #options_snp="-object sev-snp-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1 -machine memory-encryption=sev0,vmport=off"
    #options_snp="-object sev-snp-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1 -machine confidential-guest-support=sev0,vmport=off"
    if [[ $CREATE_VM_ENV =~ "UPM" ]]; then
       if [[ $CREATE_VM_ENV =~ "PVTMEM" ]]; then
            options_snp="-object sev-snp-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1,kernel-hashes=on -machine memory-encryption=sev0,vmport=off,memory-backend=${memId}"
            #options_snp="-object sev-snp-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1 -machine memory-encryption=sev0,vmport=off,memory-backend=${memId}"
       else
            echo "Requires PVTMEM"
	    exit 1
       fi
    else
        options_snp="-object sev-snp-guest,id=sev0,cbitpos=${CBITPOS},reduced-phys-bits=1,policy=${SNP_GUEST_POLICY} -machine confidential-guest-support=sev0"
    fi

    [[ $DEBUG_PRINT ]] && echo "options_snp:${options_snp}"
    options="${options} ${options_snp}"
fi

if [[ $CREATE_VM_ENV =~ "OVMF" ]]; then
    options_ovmf="-drive if=pflash,format=raw,unit=0,file=${OVMF_CODE},readonly=on"

    if [[ $CREATE_VM_ENV =~ "OVMFS" ]]; then
        if [[ ! -f ${ovmfVarsFile} ]]; then
            echo "Copy ${OVMF_VARS} to ${ovmfVarsFile} "
            cp ${OVMF_VARS} ${ovmfVarsFile}
        fi
        options_ovmf="${options_ovmf} -drive if=pflash,format=raw,unit=1,file=${ovmfVarsFile}"
    fi

    [[ $DEBUG_PRINT ]] && echo "options_ovmf:${options_ovmf}"
    options="${options} ${options_ovmf}"
fi

if [[ $CREATE_VM_ENV =~ "DEBUG" ]]; then
    options_ovmfDbg="-debugcon file:${ovmfDebugLog} -global isa-debugcon.iobase=0x402"
    [[ $DEBUG_PRINT ]] && echo "options_ovmfDbg:${options_ovmfDbg}"
    options="${options} ${options_ovmfDbg}"
fi

if [[ $CREATE_VM_ENV =~ "TPM" ]]; then
    tpmId="tpm${vm_num}"
    options_tpm="-chardev socket,id=chrtpm,path=${tpmSockFile} -tpmdev emulator,id=${tpmId},chardev=chrtpm -device tpm-tis,tpmdev=${tpmId}" 
    [[ $DEBUG_PRINT ]] && echo "options_tpm:${options_tpm}"
    options="${options} ${options_tpm}"
fi

if [[ $CREATE_VM_ENV =~ "DIRECT" ]]; then
    options_direct="-kernel ${KERNEL_IMG}"
    if [[ ! -z ${INITRD_IMG} ]]; then
        options_direct="${options_direct} -initrd ${INITRD_IMG}"
    fi
    if [[ ! -z ${APPEND_STR} ]]; then
        options_direct_append="${APPEND_STR}"
    fi

    [[ $DEBUG_PRINT ]] && echo "options_direct:${options_direct}"
    options="${options} ${options_direct}"
fi

#Record the arguments of the program for this VM before executing Qemu
tmpFile=$(mktemp)
prog_base=$(basename $0)
prog_vm="$prog_base $1"
shift
args_vm="$@"
tmpFile=$(mktemp)
grep "${prog_vm}" $createVmLogFile >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    grep -v "${prog_vm}" $createVmLogFile > ${tmpFile}
    mv ${tmpFile} $createVmLogFile
fi
echo "${prog_vm} : ${args_vm}" >> $createVmLogFile

#gdb -q --args ${QEMU} $options

if [[ -z ${options_direct_append} ]]; then
    echo "${QEMU} ${options}" | tee $createVmCmdFile
    ${QEMU} ${options}
else
    echo "${QEMU} ${options} -append \"${options_direct_append}\"" | tee $createVmCmdFile
    ${QEMU} ${options} -append "${options_direct_append}"
fi
