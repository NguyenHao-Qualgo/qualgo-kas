# Kas demo

Using to demonstrate various kas build

## Setup

```
pip3 install kas # or
pipx install kas
```

## Demo Projects

### Build

kas build --update kas/jetson-orin-nano-devkit-nvme.yml

### Output Artifacts
Once the build completes, all deployable files are located at: build/tmp/deploy/images/jetson-orin-nano-devkit-nvme/
+ demo-image-base-jetson-orin-nano-devkit-nvme.tegraflash.tar.gz (For flashing)

### Scripts
#### genKeys.sh
+ This script generates a UEFI Secure Boot key hierarchy and signing keys for three payloads:
    - `uefi1.efi`
    - `uefi2.efi`
    - Linux kernel `Image`
    - initrd (TODO?)

+ It outputs both:
    - **X.509 keys/certificates** used for signing (`*.key`, `*.crt`)
    - **UEFI enrollment artifacts** (`*.esl`, `*.auth`) used to enroll keys into firmware (e.g., via `AutoEnroll.efi`)

#### gen_dts.sh
+ This script generates an NVIDIA-style **UEFI default Secure Boot keys** Device Tree overlay:
    - `UefiDefaultSecurityKeys.dts`

+ It embeds pre-built EFI Signature Lists (`.esl`) for:
    - **PK** (Platform Key)
    - **KEK** (Key Exchange Key)
    - **db** (Signature Database / trust store)

+ UefiDefaultSecurityKeys.dts now can be used for tegra-uefi-keys-dtb.bbappend along with TEGRA_UEFI_USE_SIGNED_FILES = "true"