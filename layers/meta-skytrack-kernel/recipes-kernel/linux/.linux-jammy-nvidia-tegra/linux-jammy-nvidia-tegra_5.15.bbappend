FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://enable-kprobes.cfg"

do_compile:prepend() {
    oe_runmake -C ${S} O=${B} olddefconfig
    KCONFIG_ALLCONFIG=${WORKDIR}/enable-kprobes.cfg \
        oe_runmake -C ${S} O=${B} olddefconfig
    grep -E '^(CONFIG_XIP_KERNEL|CONFIG_KPROBES|CONFIG_KPROBE_EVENTS|CONFIG_KALLSYMS)=' ${B}/.config || true
}

#do_configure:append() {
#    oe_runmake -C ${S} O=${B} olddefconfig
#    ${S}/scripts/config --file ${B}/.config --enable KPROBES --enable KPROBE_EVENTS
#    oe_runmake -C ${S} O=${B} olddefconfig
#}
