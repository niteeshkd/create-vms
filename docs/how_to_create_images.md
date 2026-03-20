Ubuntu Image:
curl -LO https://cloud-images.ubuntu.com/noble/20250805/noble-server-cloudimg-amd64.img
cp noble-server-cloudimg-amd64.img disk1.img
qemu-img resize disk1.img 20G
