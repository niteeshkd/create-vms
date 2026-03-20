# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a QEMU VM creation toolkit focused on confidential computing. It supports AMD SEV/SEV-SNP, Intel TDX, GPU passthrough, TPM, and various persistent memory backends. Scripts are bash-based and require root/sudo to run QEMU.

## Setup

1. Edit `test.env` to set `QEMU` binary path and directory variables (`TEST_DIR`, `IMAGE_DIR`, `TMP_DIR`).
2. Source the env before running scripts: `source test.env`
3. Dependencies: `genisoimage`, `qemu-system-x86`, `qemu-utils`, optionally `swtpm`

## Common Commands

**Create disk + cloud-init ISO:**
```bash
./scripts/create_disk_cloudinit.sh <vm_num> URL=<image_url> [size_gb]
./scripts/create_disk_cloudinit.sh <vm_num> PATH=<local_image> [size_gb]
```

**Create VM** (requires `sudo -E` to preserve environment):
```bash
sudo -E ./scripts/create_vm.sh <vm_num> [FEATURE_FLAGS] ["extra qemu args"]
```

**Create TPM socket** (before launching VM with TPM flag):
```bash
./scripts/create_tpmsock.sh <vm_num>
```

**Create cloud-init ISO from custom YAML:**
```bash
./scripts/create_cloudinit.sh <vm_num> <user_data.yaml>
```

## Architecture

### Entry Points
- `scripts/create_vm.sh` — main script; builds and executes QEMU command from modular option blocks
- `scripts/create_disk_cloudinit.sh` — provisions disk image and cloud-init ISO for a VM
- `examples/` — standalone reference QEMU invocations (not meant to be sourced/called by other scripts)

### Feature Flag System (`create_vm.sh`)
The second argument to `create_vm.sh` is an underscore-separated list of feature flags (e.g., `SNP_OVMF_TAPNET_DEBUG`). The script parses these with `grep` pattern matching to conditionally build QEMU arguments:

| Category | Flags |
|---|---|
| Security | `SEV`, `SNP`, `UPM` |
| Firmware | `OVMF`, `OVMFS`, `DEBUG` |
| Memory backends | `MEMFD`, `PVTMEM`, `TMPSHM`, `DEVDAXSHM`, `FSDAXSHM`, `MEMFILE` |
| Networking | `TAPNET`, `USERNET` |
| Boot | `DIRECT` (direct kernel boot) |
| Hardware | `GPU`, `TPM` |
| Monitoring | `QGA`, `QMP`, `MON` |

Machine type is `q35` for SEV/SNP, `pc` otherwise. CPU is `EPYC` for SEV, `EPYC-v4` for SNP, `host` otherwise.

### Configuration (`test.env`)
All path and port variables are centralized here. Key variables:
- `QEMU` — path to QEMU binary
- `IMAGE_DIR` — where disk images (`disk{n}.img`) and ISOs (`nocloud{n}.iso`) are stored
- `TMP_DIR` — sockets and temp files (TPM socket, QGA socket, monitor socket)
- `SSHPORT0`, `MONPORT0`, `QMPPORT0` — base ports; VM `n` uses base + n
- `OVMF_CODE`, `OVMF_VARS` — UEFI firmware paths
- `KERNEL_IMG`, `INITRD_IMG`, `APPEND_STR` — for `DIRECT` boot
- `GPU_ADDR` — PCI address for GPU passthrough (e.g., `0000:3b:00.0`)
- `DEVDAX_FILE`, `FSDAX_MNT`, `TMPFS_MNT` — persistent memory device paths

### Cloud-Init Templates (`cloud-init/`)
- `user_data.yaml` — standard setup (creates `test` user, injects SSH key from `~/.ssh/id_ed25519.pub`)
- `user_data_snp.yaml` — SNP variant that additionally runs attestation report generation and uploads to a server

### Accessing Running VMs
- **SSH (USERNET):** `ssh -p $((SSHPORT0 + vm_num)) test@localhost`
- **Monitor (MON):** `telnet localhost $((MONPORT0 + vm_num))`
- **QMP:** `telnet localhost $((QMPPORT0 + vm_num))`
