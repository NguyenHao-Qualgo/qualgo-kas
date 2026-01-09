#!/usr/bin/env python3
import sys

KEY = bytes([
    0x3A, 0x7F, 0x21, 0x5C,
    0x99, 0xDE, 0x42, 0x10,
    0xAB, 0xCD, 0x01, 0x23,
    0x45, 0x67, 0x89, 0xFE
])

def xor_encrypt(inp, outp):
    data = open(inp, "rb").read()
    res = bytearray(len(data))
    for i, b in enumerate(data):
        res[i] = b ^ KEY[i % len(KEY)]
    open(outp, "wb").write(res)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: xor_encrypt.py in out")
        sys.exit(1)
    xor_encrypt(sys.argv[1], sys.argv[2])
