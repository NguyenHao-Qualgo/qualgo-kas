DESCRIPTION = "Initramfs early boot scripts"
LICENSE = "CLOSED"
INSANE_SKIP:${PN} += "license buildpaths"

SRC_URI += "file://load-modules.sh"

S = "${WORKDIR}"

do_install() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/load-modules.sh ${D}${sysconfdir}/init.d/load-modules
    install -d ${D}${sysconfdir}/rcS.d
    ln -sf ../init.d/load-modules ${D}${sysconfdir}/rcS.d/S05load-modules
}

FILES:${PN} += "${sysconfdir}/init.d/load-modules ${sysconfdir}/rcS.d/S05load-modules"
