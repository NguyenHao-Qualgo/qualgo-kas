#!/usr/bin/env bash
set -e

# Simple helper to generate a Secure Boot key hierarchy and three
# separate signing keys for:
#   - uefi1.efi
#   - uefi2.efi
#   - kernel Image
#
# Usage:
#   ./gen-secureboot-keys.sh  [output-dir]
#
# If output-dir is not provided, ./keys will be used.

KEY_DIR="${1:-$(pwd)/keys}"
DAYS=3650

mkdir -p "${KEY_DIR}"
cd "${KEY_DIR}"

echo "Generating Secure Boot keys into: ${KEY_DIR}"

###############################################################################
# 1. Platform Key (PK)
###############################################################################
if [ ! -f PK.key ]; then
    echo "Generating PK.key / PK.crt..."
    openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes \
        -subj "/CN=QUALGO PK/" \
        -keyout PK.key \
        -out PK.crt \
        -days ${DAYS}
fi

###############################################################################
# 2. Key Exchange Key (KEK)
###############################################################################
if [ ! -f KEK.key ]; then
    echo "Generating KEK.key / KEK.crt..."
    openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes \
        -subj "/CN=QUALGO KEK/" \
        -keyout KEK.key \
        -out KEK.crt \
        -days ${DAYS}
fi

###############################################################################
# 3. Three separate signing keys/certs for uefi1, uefi2, kernel
###############################################################################
if [ ! -f sign-uefi1.key ]; then
    echo "Generating sign-uefi1.key / sign-uefi1.crt..."
    openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes \
        -subj "/CN=QUALGO DB uefi1/" \
        -keyout sign-uefi1.key \
        -out sign-uefi1.crt \
        -days ${DAYS}
fi

if [ ! -f sign-uefi2.key ]; then
    echo "Generating sign-uefi2.key / sign-uefi2.crt..."
    openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes \
        -subj "/CN=QUALGO DB uefi2/" \
        -keyout sign-uefi2.key \
        -out sign-uefi2.crt \
        -days ${DAYS}
fi

if [ ! -f sign-kernel.key ]; then
    echo "Generating sign-kernel.key / sign-kernel.crt..."
    openssl req -new -x509 -newkey rsa:4096 -sha256 -nodes \
        -subj "/CN=QUALGO DB kernel/" \
        -keyout sign-kernel.key \
        -out sign-kernel.crt \
        -days ${DAYS}
fi

###############################################################################
# 4. Build db.esl from the three signing certs
#    - All three certs will be placed into DB, so firmware will accept
#      binaries signed by any of them.
###############################################################################
# Owner GUID for ESL entries (you can choose any UUID you like)
DB_OWNER_GUID="01234567-89ab-cdef-0123-456789abcdef"

echo "Generating DB ESL from all three signing certs..."

cert-to-efi-sig-list -g ${DB_OWNER_GUID} sign-uefi1.crt db-uefi1.esl
cert-to-efi-sig-list -g ${DB_OWNER_GUID} sign-uefi2.crt db-uefi2.esl
cert-to-efi-sig-list -g ${DB_OWNER_GUID} sign-kernel.crt db-kernel.esl

cat db-uefi1.esl db-uefi2.esl db-kernel.esl > db.esl

###############################################################################
# 5. Create PK.auth, KEK.auth and db.auth for enrollment (for AutoEnroll.efi)
###############################################################################
# GUIDs for variable owners
PK_GUID="8be4df61-93ca-11d2-aa0d-00e098032b8c"
KEK_GUID="8be4df61-93ca-11d2-aa0d-00e098032b8c"
DB_GUID="d719b2cb-3d3a-4596-a3bc-dad00e67656f"

echo "Creating PK.esl and PK.auth..."
cert-to-efi-sig-list -g ${PK_GUID} PK.crt PK.esl
sign-efi-sig-list -k PK.key -c PK.crt PK PK.esl PK.auth

echo "Creating KEK.esl and KEK.auth..."
cert-to-efi-sig-list -g ${KEK_GUID} KEK.crt KEK.esl
sign-efi-sig-list -k PK.key -c PK.crt KEK KEK.esl KEK.auth

echo "Creating db.auth with three signing certs..."
sign-efi-sig-list -k KEK.key -c KEK.crt db db.esl db.auth

echo "Done."
echo "Generated keys and auth files in: ${KEY_DIR}"
echo "  - PK.key / PK.crt / PK.auth"
echo "  - KEK.key / KEK.crt / KEK.auth"
echo "  - sign-uefi1.key / sign-uefi1.crt"
echo "  - sign-uefi2.key / sign-uefi2.crt"
echo "  - sign-kernel.key / sign-kernel.crt"
echo "  - db.esl / db.auth (db contains all three signing certs)"
