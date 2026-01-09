IMAGE_INSTALL:remove:pn-tegra-minimal-initramfs = " kernel-module-tegra-xudc"
PACKAGE_INSTALL:remove:pn-tegra-minimal-initramfs = " kernel-module-tegra-xudc"

IMAGE_INSTALL:append = " \
    busybox \
    kernel-module-nvme \
    kernel-module-pcie-tegra194 \
    kernel-module-phy-tegra194-p2u \
    kernel-module-ucsi-ccg \
    tegra-firmware-xusb \
    tegra-minimal-init \
"
