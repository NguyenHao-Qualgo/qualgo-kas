RDEPENDS:${PN}-sdk:remove = " tegra-uefi-keys-dtb"

#IMAGE_INSTALL:remove = " kernel-module-nvme "
#CORE_IMAGE_EXTRA_INSTALL:remove = " kernel-module-nvme "

IMAGE_EFI_BOOT_FILES:append = " \
    firstLoader.efi;EFI/BOOT/firstLoader.efi \
    secondLoader.enc;EFI/BOOT/secondLoader.enc \
    AutoEnroll.efi;EFI/BOOT/AutoEnroll.efi \
"