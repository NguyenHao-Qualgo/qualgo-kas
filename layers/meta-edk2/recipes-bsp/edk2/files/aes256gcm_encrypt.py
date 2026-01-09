#!/usr/bin/env python3
"""
AES-256-GCM encryption script for secondLoader.efi
Format: IV(12 bytes) + Tag(16 bytes) + Ciphertext(variable)
"""
import sys
import os

# Try pycryptodome first (doesn't require OpenSSL legacy provider)
# Fallback to cryptography if pycryptodome is not available
try:
    from Crypto.Cipher import AES
    from Crypto.Random import get_random_bytes
    USE_PYCRYPTODOME = True
except ImportError:
    try:
        # Set environment variable to avoid OpenSSL legacy provider issues
        os.environ.setdefault('CRYPTOGRAPHY_OPENSSL_NO_LEGACY', '1')
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
        from cryptography.hazmat.backends import default_backend
        USE_PYCRYPTODOME = False
    except (ImportError, RuntimeError) as e:
        print(f"Error: Need either 'pycryptodome' or 'cryptography' library: {e}")
        print("Install with: pip install pycryptodome")
        sys.exit(1)

# AES-256 key (32 bytes = 256 bits)
# This key must match the key in Uefi1.c
KEY = bytes([
    0x3A, 0x7F, 0x21, 0x5C, 0x99, 0xDE, 0x42, 0x10,
    0xAB, 0xCD, 0x01, 0x23, 0x45, 0x67, 0x89, 0xFE,
    0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0,
    0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88
])

def aes256gcm_encrypt_cryptography(inp, outp):
    """Encrypt using cryptography library"""
    data = open(inp, "rb").read()
    
    # Generate random IV (12 bytes for GCM)
    iv = os.urandom(12)
    
    # Encrypt
    # AESGCM.encrypt() returns: ciphertext + tag (tag is appended at the end)
    aesgcm = AESGCM(KEY)
    encrypted = aesgcm.encrypt(iv, data, None)
    
    # Extract tag (last 16 bytes) and ciphertext
    tag = encrypted[-16:]
    ct = encrypted[:-16]
    
    # Write: IV(12) + Tag(16) + Ciphertext
    with open(outp, "wb") as f:
        f.write(iv)
        f.write(tag)
        f.write(ct)

def aes256gcm_encrypt_pycryptodome(inp, outp):
    """Encrypt using pycryptodome library"""
    data = open(inp, "rb").read()
    
    # Generate random IV (12 bytes for GCM)
    iv = get_random_bytes(12)
    
    # Encrypt
    cipher = AES.new(KEY, AES.MODE_GCM, nonce=iv)
    ciphertext, tag = cipher.encrypt_and_digest(data)
    
    # Write: IV(12) + Tag(16) + Ciphertext
    with open(outp, "wb") as f:
        f.write(iv)
        f.write(tag)
        f.write(ciphertext)

def aes256gcm_encrypt(inp, outp):
    """Main encrypt function"""
    if USE_PYCRYPTODOME:
        aes256gcm_encrypt_pycryptodome(inp, outp)
    else:
        aes256gcm_encrypt_cryptography(inp, outp)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: aes256gcm_encrypt.py <input_file> <output_file>")
        print("Encrypts input file using AES-256-GCM")
        print("Output format: IV(12 bytes) + Tag(16 bytes) + Ciphertext")
        sys.exit(1)
    
    inp = sys.argv[1]
    outp = sys.argv[2]
    
    if not os.path.exists(inp):
        print(f"Error: Input file '{inp}' not found")
        sys.exit(1)
    
    try:
        aes256gcm_encrypt(inp, outp)
        print(f"Encrypted {inp} -> {outp}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

