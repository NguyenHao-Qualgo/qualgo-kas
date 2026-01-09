# Make sure we have sbsigntool available as a native tool
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " \
    file://qualgo-nvme-builtin.cfg \
    file://jetson-orin-no-xen.cfg \
"

DEPENDS:append = " sbsigntool-native"

# Append to do_deploy so we sign the final kernel image before it goes to deploy dir
do_deploy:append() {
    # Use the db key/cert configured in local.conf
    if [ -z "${KERNEL_DB_KEY}" ] || [ -z "${KERNEL_DB_CERT}" ]; then
        bberror "KERNEL_DB_KEY / KERNEL_DB_CERT not set – cannot sign kernel for UEFI Secure Boot"
        exit 1
    fi

    # Kernel image type for Jetson Orin is typically 'Image'
    kern="${DEPLOYDIR}/${KERNEL_IMAGETYPE}"

    if [ ! -f "${kern}" ]; then
        bbwarn "Kernel image ${kern} not found, skipping UEFI signing"
        return
    fi

    bbnote "Signing UEFI kernel image: ${kern}"

    sbsign --key "${KERNEL_DB_KEY}" \
           --cert "${KERNEL_DB_CERT}" \
           --output "${kern}.signed" \
           "${kern}"

    # Replace original image with signed one
    mv "${kern}.signed" "${kern}"
}

