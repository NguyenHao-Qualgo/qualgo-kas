FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \
    file://0005-autoenrol-hook-in-L4TLauncher.patch;patchdir=../edk2-nvidia \
"