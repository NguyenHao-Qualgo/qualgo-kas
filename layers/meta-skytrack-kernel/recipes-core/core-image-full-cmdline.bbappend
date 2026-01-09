# core-image-full-cmdline.bbappend
# Purpose:
#  - Add essential tools for NVMe/ESP and kernel modules
#  - (If INITRAMFS_IMAGE_BUNDLE = "0") copy initrd into /boot/initrd
#  - Generate /boot/extlinux/extlinux.conf automatically

# --- Minimal tools to partition/format/check NVMe ---
IMAGE_INSTALL:append = " \
    kernel-modules \
    nvme-cli dosfstools e2fsprogs resize2fs parted util-linux \
"

# --- (Optional) Set your DTB here (Yocto will install it under /boot/dtb) ---
# Replace the filename to your exact DTB. Example for Orin Nano devkit SUPER:
JETSON_DTB ?= "tegra234-p3768-0000+p3767-0005-nv-super.dtb"

# --- Ensure /boot/extlinux directory exists ---
ROOTFS_POSTPROCESS_COMMAND += " ensure_extlinux_dir; "
ensure_extlinux_dir () {
    install -d ${IMAGE_ROOTFS}/boot/extlinux
}

# --- If you DID NOT bundle initramfs (INITRAMFS_IMAGE_BUNDLE = "0"), copy initrd to /boot ---
# (Safe no-op when bundle=1 since no cpio will be present)
ROOTFS_POSTPROCESS_COMMAND += " copy_initrd_if_any; "
copy_initrd_if_any () {
    # Find first matching initramfs artifact
    initrd="$(ls ${DEPLOY_DIR_IMAGE}/${INITRAMFS_IMAGE}-${MACHINE}.cpio*.gz 2>/dev/null | head -n 1 || true)"
    if [ -n "$initrd" ]; then
        install -d ${IMAGE_ROOTFS}/boot
        install -m 0644 "$initrd" ${IMAGE_ROOTFS}/boot/initrd
    fi
}

# --- Write /boot/extlinux/extlinux.conf ---
#   - If bundle=1: no INITRD line
#   - If /boot/initrd exists: write INITRD line
ROOTFS_POSTPROCESS_COMMAND += " write_extlinux_conf; "
write_extlinux_conf () {
    IMAGE_PATH="/boot/Image"
    DTB_PATH="/boot/dtb/${JETSON_DTB}"
    EXTCONF="${IMAGE_ROOTFS}/boot/extlinux/extlinux.conf"
    INITRD_LINE=""

    # Check if a separate initrd file exists (bundle=0 case)
    if [ -f "${IMAGE_ROOTFS}/boot/initrd" ]; then
        INITRD_LINE="  INITRD /boot/initrd"
    fi

    # Fail early if kernel Image or DTB missing
    if [ ! -f "${IMAGE_ROOTFS}${IMAGE_PATH}" ]; then
        bbfatal "Missing ${IMAGE_PATH} in rootfs"
    fi
    if [ ! -f "${IMAGE_ROOTFS}${DTB_PATH}" ]; then
        bbfatal "Missing ${DTB_PATH} in rootfs (set JETSON_DTB correctly)"
    fi

    cat > "${EXTCONF}" <<'EOF_EXT'
TIMEOUT 30
DEFAULT primary
MENU TITLE L4T boot options

LABEL primary
  MENU LABEL primary kernel
  LINUX /boot/Image
  INITRD /boot/initrd
EOF_EXT

    # Append dynamic lines
    if [ -n "${INITRD_LINE}" ]; then
        echo "${INITRD_LINE}" >> "${EXTCONF}"
    fi
    echo "  FDT ${DTB_PATH}" >> "${EXTCONF}"

    # Use simple /dev path for flashing phase; you may switch to PARTUUID later on target
    echo '  APPEND ${cbootargs} root=/dev/nvme0n1p1 rw rootwait rootfstype=ext4 console=ttyTCU0,115200n8 console=tty0' >> "${EXTCONF}"
}

# --- (Optional) install DTB under /boot/dtb if your kernel packaging didn't place it ---
# If your DTB already installed, you can drop this function.
# ROOTFS_POSTPROCESS_COMMAND += " ensure_dtb_installed; "
# ensure_dtb_installed () {
#     if [ ! -f "${IMAGE_ROOTFS}/boot/dtb/${JETSON_DTB}" ]; then
#         src="$(ls ${DEPLOY_DIR_IMAGE}/${JETSON_DTB} 2>/dev/null | head -n1 || true)"
#         if [ -n "$src" ]; then
#             install -d ${IMAGE_ROOTFS}/boot/dtb
#             install -m 0644 "$src" ${IMAGE_ROOTFS}/boot/dtb/${JETSON_DTB}
#         else
#             bbfatal "Cannot find ${JETSON_DTB} in deploy to install into rootfs"
#         fi
#     fi
# }
