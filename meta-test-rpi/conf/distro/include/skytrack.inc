DISTRO = "skytrack"
DISTRO_NAME = "skytrack"
DISTRO_VERSION_BASE = "0.0.1"
DISTRO_VERSION = "${DISTRO_VERSION_BASE}+snapshot-${METADATA_REVISION}"
DISTRO_CODENAME = "scarthgap"

TARGET_VENDOR = "-skytrack"

SDK_VENDOR = "-skytracksdk"
SDK_VERSION="${DISTRO_VERSION}"

LOCALCONF_VERSION = "2"

SKYTRACK_DEFAULT_DISTRO_FEATURES ?= "largefile opengl glvnd ptest multiarch vulkan systemd pam virtualization usrmerge"
DISTRO_FEATURES:remove = " nfs alsa ext2 pulseaudio wayland"
DISTRO_FEATURES ?= "${DISTRO_FEATURES_DEFAULT} ${SKYTRACK_DEFAULT_DISTRO_FEATURES}"

PREFERRED_VERSION_linux-yocto ?= "6.6%"
PREFERRED_VERSION_linux-yocto-rt ?= "6.6%"

SDK_NAME = "${DISTRO}-${TCLIBC}-${SDKMACHINE}-${IMAGE_BASENAME}-${TUNE_PKGARCH}-${MACHINE}"
SDKPATHINSTALL = "/opt/${DISTRO}/${SDK_VERSION}"

TCLIBCAPPEND = ""

PACKAGE_CLASSES ?= "package_deb"

INIT_MANAGER = "systemd"

require conf/distro/include/no-static-libs.inc
require conf/distro/include/yocto-uninative.inc
require conf/distro/include/security_flags.inc
INHERIT += "uninative"

LICENSE_FLAGS_ACCEPTED += "commercial_faad2 commercial_x264"

USE_REDUNDANT_FLASH_LAYOUT_DEFAULT ?= "1"

PACKAGECONFIG:remove:pn-networkmanager = " dnsmasq"