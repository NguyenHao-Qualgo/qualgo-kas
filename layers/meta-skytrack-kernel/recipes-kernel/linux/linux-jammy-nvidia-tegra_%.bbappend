FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"
SRC_URI:append = " file://qualgo-ktrace.cfg"

ROOTFS_POSTPROCESS_COMMAND += "fix_sort_symlink;"

python fix_sort_symlink () {
    import os, shutil
    busybox_path = os.path.join(d.getVar('IMAGE_ROOTFS'), 'bin/busybox.nosuid')
    sort_path = os.path.join(d.getVar('IMAGE_ROOTFS'), 'usr/bin/sort')
    if os.path.exists(busybox_path):
        if os.path.islink(sort_path):
            os.unlink(sort_path)
        shutil.copyfile(busybox_path, sort_path)
}