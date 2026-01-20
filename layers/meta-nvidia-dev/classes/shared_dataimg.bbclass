DATAIMG_TYPE ?= "ext4"
DATAIMG_SIZE_MB ?= "100"
DATAIMG_LABEL ?= "SHARED_DATA"
DATAIMG_DIR ?= "data"
IMAGE_ROOTFS_EXCLUDE_PATH += " ${DATAIMG_DIR}"

# Follow tegra falsh
DATAFILE ?= "${IMAGE_BASENAME}-${MACHINE}.dataimg"
IMAGE_TEGRAFLASH_DATA ?= "${IMGDEPLOYDIR}/${IMAGE_LINK_NAME}.dataimg"

IMAGE_TYPEDEP:tegraflash += "shared_dataimg"


IMAGE_CMD:shared_dataimg() {
    root_dir_copy_opts="-d ${IMAGE_ROOTFS}/${DATAIMG_DIR}"
    if [ ! -d "${IMAGE_ROOTFS}/${DATAIMG_DIR}" ]; then
        echo "Not found anything at ${IMAGE_ROOTFS}/${DATAIMG_DIR}, create empty data partition"
        root_dir_copy_opts=""
    fi

    dd if=/dev/zero of="${WORKDIR}/data.${DATAIMG_TYPE}" count=0 bs=1M seek=${DATAIMG_SIZE_MB}
    mkfs.${DATAIMG_TYPE} \
        "${WORKDIR}/data.${DATAIMG_TYPE}" \
        $root_dir_copy_opts \
        -L ${DATAIMG_LABEL} -F
    install -m 0644 "${WORKDIR}/data.${DATAIMG_TYPE}" "${IMAGE_TEGRAFLASH_DATA}"

}

do_image_shared_dataimg[depends] += "e2fsprogs-native:do_populate_sysroot"