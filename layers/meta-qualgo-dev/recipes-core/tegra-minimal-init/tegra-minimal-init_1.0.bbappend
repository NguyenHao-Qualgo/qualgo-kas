FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " ${@bb.utils.contains('QUALGO_FEATURES','qualgo-boot-pxe',' file://init','',d)}"

do_install:append() {
    if ${@bb.utils.contains('QUALGO_FEATURES','qualgo-boot-pxe','true','false',d)}; then
        if [ -f ${D}/init ]; then
            mv ${D}/init ${D}/init.legacy || true
        fi

        install -m 0755 ${WORKDIR}/init ${D}/init
    fi
}
