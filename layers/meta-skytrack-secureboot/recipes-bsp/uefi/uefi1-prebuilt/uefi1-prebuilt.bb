SUMMARY = "UEFI chain loader: uefi1 (decrypt) + encrypted uefi2 + AutoEnroll"
LICENSE = "CLOSED"
INSANE_SKIP:${PN} += "license buildpaths"

PN = "uefi1-prebuilt"
PV = "1.0"

SRC_URI = "file://aes256gcm_encrypt.py \
           "

S = "${WORKDIR}"

# Default EFI boot directory (ESP path inside rootfs)
EFI_BOOT_DIR ?= "/EFI/BOOT"

# We need sbsign to sign PE/COFF binaries, cryptography library for encryption, and edk2-bootloader-firmware
# Try cryptography first, fallback to pycryptodome if needed
DEPENDS:append = " sbsigntool-native python3-cryptography-native python3-pycryptodome-native edk2-bootloader-firmware"

inherit deploy

do_compile[noexec] = "1"

do_install() {
    install -d ${D}${EFI_BOOT_DIR}

    # Get firstLoader.efi, secondLoader.efi and AutoEnroll.efi from edk2-bootloader-firmware package
    # They are installed to /boot/EFI/BOOT/ in the sysroot
    FIRSTLOADER_SOURCE="${STAGING_DIR_TARGET}/boot/EFI/BOOT/firstLoader.efi"
    SECONDLOADER_SOURCE="${STAGING_DIR_TARGET}/boot/EFI/BOOT/secondLoader.efi"
    AUTOENROLL_SOURCE="${STAGING_DIR_TARGET}/boot/EFI/BOOT/AutoEnroll.efi"

    if [ ! -f "${FIRSTLOADER_SOURCE}" ]; then
        bbfatal "uefi1-prebuilt: firstLoader.efi not found in ${FIRSTLOADER_SOURCE}. Make sure edk2-bootloader-firmware is built and populates sysroot."
    fi

    if [ ! -f "${SECONDLOADER_SOURCE}" ]; then
        bbfatal "uefi1-prebuilt: secondLoader.efi not found in ${SECONDLOADER_SOURCE}. Make sure edk2-bootloader-firmware is built and populates sysroot."
    fi

    if [ ! -f "${AUTOENROLL_SOURCE}" ]; then
        bbfatal "uefi1-prebuilt: AutoEnroll.efi not found in ${AUTOENROLL_SOURCE}. Make sure edk2-bootloader-firmware is built and populates sysroot."
    fi

    # Copy EFI files from edk2-bootloader-firmware to WORKDIR for signing
    install -m 0644 ${FIRSTLOADER_SOURCE} ${WORKDIR}/firstLoader.efi
    install -m 0644 ${SECONDLOADER_SOURCE} ${WORKDIR}/secondLoader.efi
    install -m 0644 ${AUTOENROLL_SOURCE} ${WORKDIR}/AutoEnroll.efi

    # Keep original input binaries
    install -m 0644 ${WORKDIR}/firstLoader.efi      ${WORKDIR}/firstLoader.orig.efi
    install -m 0644 ${WORKDIR}/secondLoader.efi    ${WORKDIR}/secondLoader.orig.efi
    install -m 0644 ${WORKDIR}/AutoEnroll.efi      ${WORKDIR}/AutoEnroll.orig.efi

    # Sign firstLoader.efi
    if [ -n "${UEFI1_DB_KEY}" ] && [ -n "${UEFI1_DB_CERT}" ]; then
        sbsign --key  "${UEFI1_DB_KEY}" \
               --cert "${UEFI1_DB_CERT}" \
               --output ${WORKDIR}/firstLoader.signed.efi \
               ${WORKDIR}/firstLoader.efi
        mv ${WORKDIR}/firstLoader.signed.efi ${WORKDIR}/firstLoader.efi
    else
        bbfatal "uefi1-prebuilt: UEFI1_DB_KEY / UEFI1_DB_CERT not set"
    fi

    # Sign secondLoader.efi
    if [ -n "${UEFI2_DB_KEY}" ] && [ -n "${UEFI2_DB_CERT}" ]; then
        sbsign --key  "${UEFI2_DB_KEY}" \
               --cert "${UEFI2_DB_CERT}" \
               --output ${WORKDIR}/secondLoader.signed.efi \
               ${WORKDIR}/secondLoader.efi
        mv ${WORKDIR}/secondLoader.signed.efi ${WORKDIR}/secondLoader.efi
    else
        bbfatal "uefi1-prebuilt: UEFI2_DB_KEY / UEFI2_DB_CERT not set"
    fi

    # Install signed firstLoader and AutoEnroll into ESP
    install -m 0644 ${WORKDIR}/firstLoader.efi ${D}${EFI_BOOT_DIR}/firstLoader.efi
    install -m 0644 ${WORKDIR}/AutoEnroll.orig.efi ${D}${EFI_BOOT_DIR}/AutoEnroll.efi

    # Encrypt signed secondLoader.efi into secondLoader.enc using AES-256-GCM
    # Format: IV(12 bytes) + Tag(16 bytes) + Ciphertext
    # Use nativepython3 to ensure we use the native cryptography library
    # Set CRYPTOGRAPHY_OPENSSL_NO_LEGACY to avoid OpenSSL 3.0 legacy provider issues
    CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1 nativepython3 ${WORKDIR}/aes256gcm_encrypt.py ${WORKDIR}/secondLoader.efi ${WORKDIR}/secondLoader.enc

    if [ ! -f "${WORKDIR}/secondLoader.enc" ]; then
        bbfatal "uefi1-prebuilt: encryption step did not produce secondLoader.enc"
    fi

    install -m 0644 ${WORKDIR}/secondLoader.enc ${D}${EFI_BOOT_DIR}/secondLoader.enc
}

do_deploy() {
    install -d ${DEPLOYDIR}
    install -m 0644 ${D}${EFI_BOOT_DIR}/firstLoader.efi      ${DEPLOYDIR}/firstLoader.efi
    install -m 0644 ${D}${EFI_BOOT_DIR}/secondLoader.enc     ${DEPLOYDIR}/secondLoader.enc
    install -m 0644 ${D}${EFI_BOOT_DIR}/AutoEnroll.efi       ${DEPLOYDIR}/AutoEnroll.efi
}

addtask deploy after do_install before do_build

FILES:${PN} = "${EFI_BOOT_DIR}"
