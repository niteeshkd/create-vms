#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "$0 <vm_num> <src_img> [<size_GB>]"
    echo "where"
    echo " vm_num   = Seqeunce number of the VM"
    echo " src_img  = Location of the .img file with prefix URL or PATH"
    echo " size_GB  = Size of the disk in GB"
    echo "Examples:"
    echo "$0 1 URL=https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
    echo "$0 2 PATH=/home/niteesh/sevtest/images/focal-server-cloudimg-amd64.img 20"
    exit 1
fi

vm_num=${1}
src_img=${2}
size_GB=${3:-10}

tgt_dir=${IMAGE_DIR}

#echo "vm_num=$vm_num src_img=${src_img} tgt_dir=$tgt_dir size_GB=$size_GB"

echo $src_img | grep -e URL -e PATH >/dev/null
if [[ $? -ne 0 ]]; then
    echo "$src_img does not contain PATH or URL!".
fi
url=`echo $src_img | grep URL | cut -c 5-`
path=`echo $src_img | grep PATH | cut -c 6-`

#Some sanity checking	
if [[ ! -d $tgt_dir ]]; then
    echo "IMAGE_DIR $tgt_dir does not exist"
    exit 1
fi

echo "Creating $tgt_dir/disk${vm_num}.img ..."
if [[ $path != "" ]]; then
    cp $path $tgt_dir/disk${vm_num}.img || exit 1
else
    wget $url -O $tgt_dir/disk${vm_num}.img || exit 1 
fi

qemu-img resize $tgt_dir/disk${vm_num}.img ${size_GB}G
