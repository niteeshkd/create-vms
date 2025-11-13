#!/bin/bash
#tmpdir=$(mktemp -d)
tmpdir=./images/tmp/
identity_file="$HOME/.ssh/id_rsa.pub"

if [[ $# -lt 2 ]]; then
    echo "$0 <vm_num> <src_img> [<size_GB>]"
    echo "where"
    echo " vm_num   = Seqeunce number of the VM"
    echo " src_img  = Location of the .img file with prefix URL or PATH"
    echo " size_GB  = Size of the disk in GB"
    echo "Examples:"
    echo "$0 1 URL=https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
    echo "$0 2 URL=https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    echo "$0 0 URL=https://download.fedoraproject.org/pub/fedora/linux/releases/35/Cloud/x86_64/images/Fedora-Cloud-Base-35-1.2.x86_64.qcow2 20"
    echo "$0 3 PATH=/home/niteesh/sevtest/images/focal-server-cloudimg-amd64.img 20"
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
if [[ ! -f $identity_file ]]; then
    echo "$identity_file does not exist"
    exit 1
fi

echo "Creating $tgt_dir/disk${vm_num}.img ..."
if [[ $path != "" ]]; then
    cp $path $tgt_dir/disk${vm_num}.img || exit 1
else
    wget $url -O $tgt_dir/disk${vm_num}.img || exit 1 
fi
qemu-img resize $tgt_dir/disk${vm_num}.img ${size_GB}G

destfile="${tgt_dir}/nocloud${vm_num}.iso"
hostname="vm${vm_num}"

echo "Creating $destfile ..."

cat > $tmpdir/meta-data <<EOF
local-hostname: ${hostname}
EOF
if [ $? -ne 0 ]; then
	exit 1
fi

cat > $tmpdir/user-data <<EOF
#cloud-config

locale: en_US.UTF-8

users:
- name: test
  lock-passwd: false
  lock_passwd: false
  plain_text_passwd: test
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  ssh_authorized_keys:
    - $(cat ${identity_file})
EOF
if [ $? -ne 0 ]; then
	exit 1
fi

genisoimage  -output $destfile -input-charset iso8859-1 -volid cidata -joliet -rock $tmpdir/user-data $tmpdir/meta-data || exit 1

#rm -R $tmpdir
