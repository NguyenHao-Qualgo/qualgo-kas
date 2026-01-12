FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " ${@bb.utils.contains('QUALGO_FEATURES','qualgo-boot-pxe',' file://qualgo-nfs.cfg','',d)}"
