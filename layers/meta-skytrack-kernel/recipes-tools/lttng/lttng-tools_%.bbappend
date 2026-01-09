# FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# SRC_URI += "file://bypass-kprobes-check.patch"
# EXTRA_OEMAKE:append = " KCPPFLAGS='-DLTTNG_BYPASS_KPROBES_CHECK'"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

#EXTRA_OEMAKE:append = " KCPPFLAGS='-DLTTNG_BYPASS_KPROBES_CHECK'"
#SKIP_RECIPE[lttng-modules] = "blacklisted due to build failure"
#
#python () {
#    pn = d.getVar("PN")
#    if pn == "lttng-tools":
#        d.setVar("RDEPENDS:%s" % pn, "")
#    elif pn == "tracetools":
#        d.setVar("RDEPENDS:%s" % pn, "")
#    elif pn == "demo-nodes-cpp":
#        d.setVar("RDEPENDS:%s" % pn, "")
#}

# RDEPENDS:${PN}:remove:append:class-target = " lttng-modules"
# RDEPENDS:${PN}:remove:append:class-target = " lttng-tools"
# RDEPENDS:${PN}:remove:append:class-target = " tracetools"

