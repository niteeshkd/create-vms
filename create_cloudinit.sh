#!/bin/bash
# To use a different cloud init, type 'sudo cloud-init clean' inside the VM
#  and then apply new cloud init.
tmpdir=$(mktemp -d)

if [[ $# -lt 2 ]]; then
    echo "$0 <vm_num> <user_data>"
    echo "where"
    echo " vm_num      = Seqeunce number of the VM"
    echo " user_data   = User data file for cloud init"
    echo "Examples:"
    echo "$0 1 user_data.yaml"
    exit 1
fi

vm_num=${1}
userData=${2}

tgt_dir=${IMAGE_DIR}

#Some sanity checking	
if [[ ! -d $tgt_dir ]]; then
    echo "IMAGE_DIR $tgt_dir does not exist"
    exit 1
fi

destfile="${tgt_dir}/nocloud${vm_num}.iso"
hostname="vm${vm_num}"

echo "Creating $destfile ..."

cat > $tmpdir/meta-data <<EOF
local-hostname: ${hostname}
EOF

cat > $tmpdir/user-data <<EOF
$(cat $userData)
EOF

genisoimage  -output $destfile -input-charset iso8859-1 -volid cidata -joliet -rock $tmpdir/user-data $tmpdir/meta-data || exit 1

rm -R $tmpdir
