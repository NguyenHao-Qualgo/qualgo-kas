FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

LIC_FILES_CHKSUM = "file://LICENSE;md5=9b19e046e8f293fd8fa928a08f5ecc27"

LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

do_fetch() {
    :
}

do_unpack() {
    :
}

do_configure() {
    :
}

do_compile() {
    :
}

do_install() {
    :
}

do_compile_ptest_base() {
    :
}

do_install_ptest_base() {
    :
}

INSANE_SKIP_${PN} += "license"
INSANE_SKIP_${PN}-dev += "license"
INSANE_SKIP_${PN}-dbg += "license"
INSANE_SKIP_${PN}-staticdev += "license"
INSANE_SKIP_${PN}-nativesdk += "license"
