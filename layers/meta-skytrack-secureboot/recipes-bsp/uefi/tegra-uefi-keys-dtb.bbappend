FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append = " file://UefiDefaultSecurityKeys.dts"

python do_package_write_rpm () {
    bb.note("tegra-uefi-keys-dtb: dummy do_package_write_rpm (no RPM package generated)")
}
do_package_write_rpm[noexec] = "1"

