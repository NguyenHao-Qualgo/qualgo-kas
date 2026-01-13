#!/usr/bin/env bash
set -e

# Generate NVIDIA-style UEFI default keys DTS/DTBO from existing ESL files.
# Usage:
#   sudo ./gen_uefi_default_keys_dts_from_esl.sh <uefi_keys.conf>
#
# Expected in uefi_keys.conf (minimum):
#   UEFI_PK_ESL_FILE="PK.esl"
#   UEFI_KEK_ESL_FILE="KEK.esl"
#   UEFI_DB_ESL_FILE="db.esl"
#
# Optional:
#   UEFI_DBX_ESL_FILE_1="dbx_1.esl"
#   UEFI_DBX_ESL_FILE_2="dbx_2.esl"
#   UEFI_APPEND_KEK_ESL_FILE_1="KEK_1.esl"
#   UEFI_APPEND_KEK_ESL_FILE_2="KEK_2.esl"
#   UEFI_APPEND_DB_ESL_FILE_1="db_extra_1.esl"
#   UEFI_APPEND_DB_ESL_FILE_2="db_extra_2.esl"

trap 'echo "gen_uefi_default_keys_dts_from_esl.sh: error occurred !!!"; exit 1' ERR

dts_file="UefiDefaultSecurityKeys.dts"

if [ -z "${1:-}" ]; then
  echo "Usage: sudo $0 <uefi_keys.conf>"
  exit 1
fi

uefi_keys_conf="$1"
source "${uefi_keys_conf}"

# cd to config directory so relative paths work
uefi_keys_conf_dir="$(dirname "${uefi_keys_conf}")"
pushd "${uefi_keys_conf_dir}" > /dev/null 2>&1 || exit 1

require_file() {
  local f="$1"
  local name="$2"
  if [ -z "${f}" ]; then
    echo "${name} is empty"
    exit 1
  fi
  if [ ! -f "${f}" ]; then
    echo "${f} does not exist"
    exit 1
  fi
}

# Required ESLs
require_file "${UEFI_PK_ESL_FILE:-}"  "UEFI_PK_ESL_FILE"
require_file "${UEFI_KEK_ESL_FILE:-}" "UEFI_KEK_ESL_FILE"
require_file "${UEFI_DB_ESL_FILE:-}"  "UEFI_DB_ESL_FILE"

# Optional files: check only if set
optional_file_check() {
  local f="$1"
  if [ -n "${f}" ] && [ ! -f "${f}" ]; then
    echo "${f} does not exist"
    exit 1
  fi
}

optional_file_check "${UEFI_DBX_ESL_FILE_1:-}"
optional_file_check "${UEFI_DBX_ESL_FILE_2:-}"
optional_file_check "${UEFI_APPEND_KEK_ESL_FILE_1:-}"
optional_file_check "${UEFI_APPEND_KEK_ESL_FILE_2:-}"
optional_file_check "${UEFI_APPEND_DB_ESL_FILE_1:-}"
optional_file_check "${UEFI_APPEND_DB_ESL_FILE_2:-}"

dts_header() {
cat > "${dts_file}" << 'EOF'
/dts-v1/;
/plugin/;
/ {
    overlay-name = "UEFI default Keys";
    fragment@0 {
        target-path = "/";
        board_config {
            sw-modules = "uefi";
        };
        __overlay__ {
            firmware {
                uefi {
                    variables {
                        gNVIDIAPublicVariableGuid {
                            EnrollDefaultSecurityKeys {
                                data = [01];
                                non-volatile;
                            };
                        };
EOF
}

dbdefault_header() {
cat >> "${dts_file}" << 'EOF'
                        gEfiGlobalVariableGuid {
                            dbDefault {
                                data = [
EOF
}

dbdefault_tail() {
cat >> "${dts_file}" << 'EOF'
                                ];
                                non-volatile;
                            };
EOF
}

dbxdefault_header() {
cat >> "${dts_file}" << 'EOF'
                            dbxDefault {
                                data = [
EOF
}

dbxdefault_tail() {
cat >> "${dts_file}" << 'EOF'
                                ];
                                non-volatile;
                            };
EOF
}

kekdefault_header() {
cat >> "${dts_file}" << 'EOF'
                            KEKDefault {
                                data = [
EOF
}

kekdefault_tail() {
cat >> "${dts_file}" << 'EOF'
                                ];
                                non-volatile;
                            };
EOF
}

pkdefault_header() {
cat >> "${dts_file}" << 'EOF'
                            PKDefault {
                                data = [
EOF
}

pkdefault_tail() {
cat >> "${dts_file}" << 'EOF'
                                ];
                                non-volatile;
                            };
                        };
EOF
}

dts_tail() {
cat >> "${dts_file}" << 'EOF'
                    };
                };
            };
        };
    };
};
EOF
}

append_esl_as_hex() {
  local f="$1"
  # od prints bytes as hex, suitable for DTS "data = [ ... ]"
  od -t x1 -An "${f}" >> "${dts_file}"
}

# Build DTS
dts_header

# dbDefault
dbdefault_header
append_esl_as_hex "${UEFI_DB_ESL_FILE}"
if [ -n "${UEFI_APPEND_DB_ESL_FILE_1:-}" ]; then
  append_esl_as_hex "${UEFI_APPEND_DB_ESL_FILE_1}"
fi
if [ -n "${UEFI_APPEND_DB_ESL_FILE_2:-}" ]; then
  append_esl_as_hex "${UEFI_APPEND_DB_ESL_FILE_2}"
fi
dbdefault_tail

# dbxDefault (optional)
if [ -n "${UEFI_DBX_ESL_FILE_1:-}" ] || [ -n "${UEFI_DBX_ESL_FILE_2:-}" ]; then
  dbxdefault_header
  if [ -n "${UEFI_DBX_ESL_FILE_1:-}" ]; then
    append_esl_as_hex "${UEFI_DBX_ESL_FILE_1}"
  fi
  if [ -n "${UEFI_DBX_ESL_FILE_2:-}" ]; then
    append_esl_as_hex "${UEFI_DBX_ESL_FILE_2}"
  fi
  dbxdefault_tail
fi

# KEKDefault
kekdefault_header
append_esl_as_hex "${UEFI_KEK_ESL_FILE}"
if [ -n "${UEFI_APPEND_KEK_ESL_FILE_1:-}" ]; then
  append_esl_as_hex "${UEFI_APPEND_KEK_ESL_FILE_1}"
fi
if [ -n "${UEFI_APPEND_KEK_ESL_FILE_2:-}" ]; then
  append_esl_as_hex "${UEFI_APPEND_KEK_ESL_FILE_2}"
fi
kekdefault_tail

# PKDefault
pkdefault_header
append_esl_as_hex "${UEFI_PK_ESL_FILE}"
pkdefault_tail

dts_tail

echo "DTS generated: ${uefi_keys_conf_dir}/${dts_file}"

# Compile to DTBO if dtc exists
dts_file_base="$(basename "${dts_file%.*}")"
if command -v dtc >/dev/null 2>&1; then
  dtc -I dts -O dtb "${dts_file}" -o "${dts_file_base}.dtbo"
  echo "DTBO generated: ${uefi_keys_conf_dir}/${dts_file_base}.dtbo"
else
  echo "WARNING: dtc not found; skipping DTBO generation."
fi

popd > /dev/null 2>&1 || exit 1

