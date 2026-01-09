SUMMARY = "Build UEFI1 and UEFI2 binaries from EDK2"
LICENSE = "CLOSED"
INSANE_SKIP:${PN} += "license buildpaths"

require recipes-bsp/uefi/edk2-firmware.inc
require conf/image-uefi.conf

LIC_FILES_CHKSUM = "file://License.txt;md5=2b415520383f7964e96700ae12b4570a"

COMPATIBLE_MACHINE = "(tegra)"

SRC_URI = "${SRC_URI_EDK2};branch=${SRCBRANCH_edk2};name=edk2;destsuffix=edk2"
SRCREV_FORMAT = "edk2"

SRCREV_edk2 = "14aa197f71cc7bc7bb7ecd8184dfb062fd581d03"
SRCBRANCH_edk2 = "master"

export PACKAGES_PATH = "${S}"

SRC_URI += "file://QualgoChainPkg \
            file://aes256gcm_encrypt.py"

EDK2_ARCH      = "AARCH64"
EDK_COMPILER   = "GCC5"
EDK2_BUILD_RELEASE = "1"

EDK2_PLATFORM      = "QualgoChainPkg"
EDK2_PLATFORM_DSC  = "QualgoChainPkg/QualgoChainPkg.dsc"

EDK2_UEFI1_INF    = "QualgoChainPkg/Applications/Uefi1/Uefi1.inf"
EDK2_UEFI2_INF    = "QualgoChainPkg/Applications/Uefi2/Uefi2.inf"
EDK2_ENROLL_KEY   = "QualgoChainPkg/Applications/AutoEnroll/AutoEnroll.inf"

DEPENDS:append = " nasm-native openssl-native git-native python3-cryptography-native python3-pycryptodome-native sbsigntool-native"

do_configure:append() {
    cp -a ${WORKDIR}/QualgoChainPkg ${S}/
}

do_compile() {
    sed -i -e 's:-I \.\.:-I \.\. ${BUILD_CFLAGS} :' ${EDK_TOOLS_PATH}/Source/C/Makefiles/header.makefile
    sed -i -e 's: -luuid: -luuid ${BUILD_LDFLAGS}:g' ${EDK_TOOLS_PATH}/Source/C/*/GNUmakefile

    cp ${EDK_TOOLS_PATH}/Conf/build_rule.template ${S}/Conf/build_rule.txt
    cp ${EDK_TOOLS_PATH}/Conf/tools_def.template ${S}/Conf/tools_def.txt
    cp ${EDK_TOOLS_PATH}/Conf/target.template ${S}/Conf/target.txt

    export CC="${BUILD_CC}"
    export CXX="${BUILD_CXX}"
    export AS="${BUILD_AS}"
    export AR="${BUILD_AR}"
    export LD="${BUILD_LD}"

    oe_runmake -C ${S}/BaseTools

    PATH="${WORKSPACE}:${BTOOLS_PATH}:$PATH" \
    build \
      --arch "${EDK2_ARCH}" \
      --buildtarget "${EDK2_BUILD_MODE}" \
      --tagname "${EDK_COMPILER}" \
      --platform "${EDK2_PLATFORM_DSC}" \
      -m "${EDK2_UEFI1_INF}"

    PATH="${WORKSPACE}:${BTOOLS_PATH}:$PATH" \
    build \
      --arch "${EDK2_ARCH}" \
      --buildtarget "${EDK2_BUILD_MODE}" \
      --tagname "${EDK_COMPILER}" \
      --platform "${EDK2_PLATFORM_DSC}" \
      -m "${EDK2_UEFI2_INF}"

    PATH="${WORKSPACE}:${BTOOLS_PATH}:$PATH" \
    build \
      --arch "${EDK2_ARCH}" \
      --buildtarget "${EDK2_BUILD_MODE}" \
      --tagname "${EDK_COMPILER}" \
      --platform "${EDK2_PLATFORM_DSC}" \
      -m "${EDK2_ENROLL_KEY}"
}

do_uefi_sign() {
    BUILD_OUTPUT_DIR="${B}/Build/${EDK2_PLATFORM}/${EDK2_BUILD_MODE}_${EDK_COMPILER}/${EDK2_ARCH}"
    # Sign firstLoader.efi
    if [ -n "${UEFI1_DB_KEY}" ] && [ -n "${UEFI1_DB_CERT}" ]; then
        sbsign --key  "${UEFI1_DB_KEY}" \
               --cert "${UEFI1_DB_CERT}" \
               --output ${BUILD_OUTPUT_DIR}/Uefi1.signed.efi \
               ${BUILD_OUTPUT_DIR}/Uefi1.efi
        mv ${BUILD_OUTPUT_DIR}/Uefi1.signed.efi ${BUILD_OUTPUT_DIR}/Uefi1.efi
    else
        bbfatal "edk2-bootloader-firmware: UEFI1_DB_KEY / UEFI1_DB_CERT not set"
    fi

    # Sign secondLoader.efi
    if [ -n "${UEFI2_DB_KEY}" ] && [ -n "${UEFI2_DB_CERT}" ]; then
        sbsign --key  "${UEFI2_DB_KEY}" \
               --cert "${UEFI2_DB_CERT}" \
               --output ${BUILD_OUTPUT_DIR}/Uefi2.signed.efi \
               ${BUILD_OUTPUT_DIR}/Uefi2.efi
        mv ${BUILD_OUTPUT_DIR}/Uefi2.signed.efi ${BUILD_OUTPUT_DIR}/Uefi2.efi
    else
        bbfatal "edk2-bootloader-firmware: UEFI2_DB_KEY / UEFI2_DB_CERT not set"
    fi

    CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1 nativepython3 ${WORKDIR}/aes256gcm_encrypt.py \
        ${BUILD_OUTPUT_DIR}/Uefi2.efi ${BUILD_OUTPUT_DIR}/Uefi2.enc
}
addtask uefi_sign after do_compile before do_install

do_install() {
    BUILD_OUTPUT_DIR="${B}/Build/${EDK2_PLATFORM}/${EDK2_BUILD_MODE}_${EDK_COMPILER}/${EDK2_ARCH}"

    install -d ${D}${EFIDIR}

    [ -f ${BUILD_OUTPUT_DIR}/Uefi1.efi ] && install -m 0644 ${BUILD_OUTPUT_DIR}/Uefi1.efi ${D}${EFIDIR}/bootaa64.efi
    [ -f ${BUILD_OUTPUT_DIR}/Uefi2.enc ] && install -m 0644 ${BUILD_OUTPUT_DIR}/Uefi2.enc ${D}${EFIDIR}/secondLoader.enc
    [ -f ${BUILD_OUTPUT_DIR}/AutoEnroll.efi ] && install -m 0644 ${BUILD_OUTPUT_DIR}/AutoEnroll.efi ${D}${EFIDIR}/AutoEnroll.efi
}

do_deploy() {
    install -d ${DEPLOYDIR}

    if [ -f ${D}${EFIDIR}/bootaa64.efi ]; then
        install -m 0644 ${D}${EFIDIR}/bootaa64.efi ${DEPLOYDIR}/bootaa64.efi
    fi
    if [ -f ${D}${EFIDIR}/secondLoader.enc ]; then
        install -m 0644 ${D}${EFIDIR}/secondLoader.enc ${DEPLOYDIR}/secondLoader.enc
    fi
    if [ -f ${D}${EFIDIR}/AutoEnroll.efi ]; then
        install -m 0644 ${D}${EFIDIR}/AutoEnroll.efi ${DEPLOYDIR}/AutoEnroll.efi
    fi
}

FILES:${PN} += "${EFIDIR}"
