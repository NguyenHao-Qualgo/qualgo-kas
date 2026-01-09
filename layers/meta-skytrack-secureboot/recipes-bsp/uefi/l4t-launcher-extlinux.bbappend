# Make sure we have sbsign available
DEPENDS:append = " sbsigntool-native"

# Sign /boot/Image after it has been installed by l4t-launcher-extlinux
do_install:append() {
    if [ -z "${KERNEL_DB_KEY}" ] || [ -z "${KERNEL_DB_CERT}" ]; then
        bbfatal "KERNEL_DB_KEY / KERNEL_DB_CERT not set"
    fi

    KIMG="${D}${L4T_EXTLINUX_BASEDIR}/${KERNEL_IMAGETYPE}"
    if [ -f "${KIMG}" ]; then
        sbsign --key "${KERNEL_DB_KEY}" \
               --cert "${KERNEL_DB_CERT}" \
               --output "${KIMG}.signed" \
               "${KIMG}"
        mv "${KIMG}.signed" "${KIMG}"
    fi
}