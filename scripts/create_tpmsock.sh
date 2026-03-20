#!/bin/bash
vm_num=$1
#echo "/usr/bin/swtpm socket --daemon --tpmstate dir=${TMP_DIR} --ctrl type=unixio,path=${TMP_DIR}/tpmsock${vm_num} --log file=${TMP_DIR}/tpmsock${vm_num}.log --tpm2"
/usr/bin/swtpm socket --daemon --tpmstate dir=${TMP_DIR} --ctrl type=unixio,path=${TMP_DIR}/tpmsock${vm_num} --log file=${TMP_DIR}/tpmsock${vm_num}.log --tpm2

ps -ef | grep "tpmsock${vm_num}"
