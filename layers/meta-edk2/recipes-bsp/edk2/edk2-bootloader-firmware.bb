SUMMARY = "Build UEFI1 and UEFI2 binaries from EDK2"
LICENSE = "CLOSED"
INSANE_SKIP:${PN} += "license buildpaths"

# Source configuration:
# - Replace the git URL below with your own EDK2 repository if necessary
SRC_URI = "gitsm://github.com/tianocore/edk2.git;branch=master;protocol=https"
SRCREV = "14aa197f71cc7bc7bb7ecd8184dfb062fd581d03"

S = "${WORKDIR}/git"

inherit python3native pkgconfig

# Build-time dependencies for EDK2 tools and build system
DEPENDS += "nasm-native iasl-native util-linux-native openssl-native git-native python3-cryptography-native python3-pycryptodome-native"

# EDK2 build parameters (adjust to match your platform)
EDK2_ARCH      ?= "AARCH64"
EDK2_TOOLCHAIN ?= "GCC5"
EDK2_TARGET    ?= "RELEASE"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://QualgoChainPkg"


# EDK2 platform and modules (YOU MUST ADJUST THESE)
QUALGOCHAIN_DSC ?= "QualgoChainPkg/QualgoChainPkg.dsc"
EDK2_UEFI1_INF    ?= "QualgoChainPkg/Applications/Uefi1/Uefi1.inf"
EDK2_UEFI2_INF    ?= "QualgoChainPkg/Applications/Uefi2/Uefi2.inf"
EDK2_ENROLL_KEY   ?= "QualgoChainPkg/Applications/AutoEnroll/AutoEnroll.inf"

do_configure:append() {
    oe_runmake -C ${S}/BaseTools \
        CC="${BUILD_CC}" \
        CXX="${BUILD_CXX}" \
        LD="${BUILD_LD}" \
        AR="${BUILD_AR}"
    cp -a ${WORKDIR}/QualgoChainPkg ${S}/
}

do_compile:append() {
    export WORKSPACE=${S}
    export PACKAGES_PATH=${S}
    export EDK_TOOLS_PATH=${S}/BaseTools

    # Set GCC5_AARCH64_PREFIX for AARCH64 cross-compilation
    # EDK2 build system requires this environment variable to find the cross-compiler
    export GCC5_AARCH64_PREFIX="${TARGET_PREFIX}"

    bbnote "Setting GCC5_AARCH64_PREFIX=${GCC5_AARCH64_PREFIX}"

    # Source edksetup.sh to set up EDK2 build environment
    . ${S}/edksetup.sh

    bbnote "Building Uefi1..."
    build -a ${EDK2_ARCH} -t ${EDK2_TOOLCHAIN} -b ${EDK2_TARGET} \
          -D BUILD_DATE_TIME=2025-12-15 \
          -p ${QUALGOCHAIN_DSC} \
          -m ${EDK2_UEFI1_INF}

    bbnote "Building Uefi2..."
    build -a ${EDK2_ARCH} -t ${EDK2_TOOLCHAIN} -b ${EDK2_TARGET} \
          -D BUILD_DATE_TIME=2025-12-15 \
          -p ${QUALGOCHAIN_DSC} \
          -m ${EDK2_UEFI2_INF}

    bbnote "Building AutoEnroll..."
    build -a ${EDK2_ARCH} -t ${EDK2_TOOLCHAIN} -b ${EDK2_TARGET} \
          -D BUILD_DATE_TIME=2025-12-15 \
          -p ${QUALGOCHAIN_DSC} \
          -m ${EDK2_ENROLL_KEY}
}

do_install:append() {
    install -d ${D}/boot/EFI/BOOT

    # EDK2 output path structure: Build/QualgoChainPkg/${EDK2_TARGET}_${EDK2_TOOLCHAIN}/${EDK2_ARCH}/
    BUILD_OUTPUT_DIR="${S}/Build/QualgoChainPkg/${EDK2_TARGET}_${EDK2_TOOLCHAIN}/${EDK2_ARCH}"

    bbnote "Looking for EFI files in ${BUILD_OUTPUT_DIR}"

    # Install Uefi1.efi as firstLoader.efi (BASE_NAME from Uefi1.inf is "Uefi1")
    if [ -f ${BUILD_OUTPUT_DIR}/Uefi1.efi ]; then
        install -m 0644 ${BUILD_OUTPUT_DIR}/Uefi1.efi ${D}/boot/EFI/BOOT/firstLoader.efi
        bbnote "Installed Uefi1.efi as firstLoader.efi"
    else
        bberror "Uefi1.efi not found in ${BUILD_OUTPUT_DIR}"
        exit 1
    fi

    # Install Uefi2.efi as secondLoader.efi (BASE_NAME from Uefi2.inf is "Uefi2")
    if [ -f ${BUILD_OUTPUT_DIR}/Uefi2.efi ]; then
        install -m 0644 ${BUILD_OUTPUT_DIR}/Uefi2.efi ${D}/boot/EFI/BOOT/secondLoader.efi
        bbnote "Installed Uefi2.efi as secondLoader.efi"
    else
        bberror "Uefi2.efi not found in ${BUILD_OUTPUT_DIR}"
        exit 1
    fi

    # Install AutoEnroll.efi (BASE_NAME from AutoEnroll.inf is "AutoEnroll")
    if [ -f ${BUILD_OUTPUT_DIR}/AutoEnroll.efi ]; then
        install -m 0644 ${BUILD_OUTPUT_DIR}/AutoEnroll.efi ${D}/boot/EFI/BOOT/AutoEnroll.efi
        bbnote "Installed AutoEnroll.efi"
    else
        bberror "AutoEnroll.efi not found in ${BUILD_OUTPUT_DIR}"
        exit 1
    fi
}

FILES:${PN} = " \
    /boot/EFI/BOOT/firstLoader.efi \
    /boot/EFI/BOOT/secondLoader.efi \
    /boot/EFI/BOOT/AutoEnroll.efi \
"

# Populate sysroot so other recipes can access the EFI files
SYSROOT_DIRS += "/boot"