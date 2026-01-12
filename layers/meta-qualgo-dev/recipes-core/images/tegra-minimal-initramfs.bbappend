
PACKAGE_INSTALL:append = " ${@bb.utils.contains('QUALGO_FEATURES','qualgo-boot-pxe',' nv-kernel-module-r8168','',d)}"
