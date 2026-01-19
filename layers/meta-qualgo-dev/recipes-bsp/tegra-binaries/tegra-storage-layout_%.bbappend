FILESEXTRAPATHS:prepend := "${THISDIR}/${BPN}:"

SRC_URI:append = " file://custom.xml"

PARTITION_FILE_EXTERNAL = "${WORKDIR}/custom.xml"