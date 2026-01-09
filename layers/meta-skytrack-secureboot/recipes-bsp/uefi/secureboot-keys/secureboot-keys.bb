SUMMARY = "UEFI Secure Boot key bundle (public certs/.auth)"
LICENSE = "CLOSED"
INSANE_SKIP:${PN} += "license buildpaths"

PN = "secureboot-keys"
EFI_KEY_DIR ?= "/keys"

do_install() {
    install -d ${D}${EFI_KEY_DIR}
    install -m 0644 ${SECUREBOOT_KEYS_DIR}/db.auth  ${D}${EFI_KEY_DIR}/db.auth
    install -m 0644 ${SECUREBOOT_KEYS_DIR}/KEK.auth ${D}${EFI_KEY_DIR}/KEK.auth
    install -m 0644 ${SECUREBOOT_KEYS_DIR}/PK.auth  ${D}${EFI_KEY_DIR}/PK.auth
}

FILES:${PN} = "\
    ${EFI_KEY_DIR} \
    ${EFI_KEY_DIR}/db.auth \
    ${EFI_KEY_DIR}/KEK.auth \
    ${EFI_KEY_DIR}/PK.auth \
"