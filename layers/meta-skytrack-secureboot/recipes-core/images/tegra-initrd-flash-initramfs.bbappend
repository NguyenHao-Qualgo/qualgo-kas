# conf/local.conf hoặc machine.conf
TEGRA_INITRD_FLASH_INSTALL:append = " \
    kernel-module-nvme-core \
    kernel-module-nvme \
    kernel-module-typec \
    kernel-module-typec-ucsi \
    kernel-module-ucsi-ccg \
    kernel-module-tegra-mce \
    kernel-module-watchdog-tegra-t18x \
"

PACKAGE_INSTALL:append = "\
    kernel-module-nvme \
    kernel-module-pcie-tegra194 \
    kernel-module-phy-tegra194-p2u \
    kernel-module-ucsi-ccg \
"