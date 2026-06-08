#!/usr/bin/env python3
"""
check_mapping.py ? Admin verification tool for the encrypted student map.

Reads docs/encrypted_map.json and docs/student_index.json and reports:
  - Total entries
  - Coverage (students with encrypted entries)
  - Optional: test decryption for a specific student (--test mode)

Usage:
  # Show summary only
  python tools/check_mapping.py

  # Test decryption for a specific student
  python tools/check_mapping.py --test --nisn 1234567890 --dob 01012010
"""

import argparse
import hashlib
import json
import sys
import base64
from pathlib import Path

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

SALT = b"mumtaza-tka-2026"
PBKDF2_ITERATIONS = 100_000
KEY_LENGTH = 32

BASE_DIR = Path(__file__).resolve().parent.parent
ENCRYPTED_PATH = BASE_DIR / "docs" / "encrypted_map.json"
INDEX_PATH = BASE_DIR / "docs" / "student_index.json"


def sha256hex(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def derive_key(nisn: str, ddmmyyyy: str) -> bytes:
    password = f"{nisn}:{ddmmyyyy}".encode("utf-8")
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=KEY_LENGTH,
        salt=SALT,
        iterations=PBKDF2_ITERATIONS,
    )
    return kdf.derive(password)


def load_json(path: Path, label: str):
    if not path.exists():
        print(f"[ERROR] {label} not found: {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def show_summary(enc_map, idx_map):
    print("=" * 55)
    print("  ENCRYPTED MAP ? SUMMARY")
    print("=" * 55)
    print(f"  Student index entries:      {len(idx_map)}")
    print(f"  Encrypted map entries:      {len(enc_map)}")
    print(f"  Coverage:                   {len(enc_map)}/{len(idx_map)} "
          f"({100 * len(enc_map) // len(idx_map) if idx_map else 0}%)")
    missing = [h for h in idx_map if h not in enc_map]
    if missing:
        print(f"\n  !!  Students WITHOUT encrypted entry ({len(missing)}):")
        for h in missing[:10]:
            print(f"       {idx_map[h]}")
        if len(missing) > 10:
            print(f"       ... and {len(missing) - 10} more")
    extra = [h for h in enc_map if h not in idx_map]
    if extra:
        print(f"\n  !!  Orphaned encrypted entries (no index): {len(extra)}")
    print("=" * 55)


def test_decryption(enc_map, idx_map, nisn, dob):
    hash_nisn = sha256hex(nisn)
    name = idx_map.get(hash_nisn, "(unknown)")

    if hash_nisn not in enc_map:
        print(f"[FAIL] No encrypted entry for NISN {nisn} ({name})")
        print("       Check that drive_files.csv included this NISN.")
        sys.exit(1)

    enc = enc_map[hash_nisn]
    try:
        key = derive_key(nisn, dob)
        iv = base64.b64decode(enc["iv"])
        ct = base64.b64decode(enc["ciphertext"])
        tag = base64.b64decode(enc["tag"])
        aesgcm = AESGCM(key)
        decrypted = aesgcm.decrypt(iv, ct + tag, None)
        payload = json.loads(decrypted.decode("utf-8"))
    except Exception as e:
        print(f"[FAIL] Decryption failed for NISN {nisn} ({name}): {e}")
        print("       Check that NISN and dob are correct.")
        sys.exit(1)

    # Verify payload integrity
    expected_name = payload.get("nama", "")
    if expected_name != name:
        print(f"[WARN] Name mismatch: index says '{name}', payload says '{expected_name}'")

    print(f"[?] Decrypted OK: {payload.get('nama', '?')} (NISN: {nisn})")
    print(f"    Nomor Peserta: {payload.get('nomor_peserta', '?')}")
    print(f"    ? fileId present ({len(payload.get('fileId', ''))} chars)")
    # Deliberately NOT printing the fileId value


def main():
    parser = argparse.ArgumentParser(
        description="Check and verify encrypted student map"
    )
    parser.add_argument("--test", action="store_true",
                        help="Test decryption for a specific student")
    parser.add_argument("--nisn", type=str, default="",
                        help="Student NISN (for --test)")
    parser.add_argument("--dob", type=str, default="",
                        help="Birth date in ddmmyyyy format (for --test)")
    args = parser.parse_args()

    enc_map = load_json(ENCRYPTED_PATH, "encrypted_map.json")
    idx_map = load_json(INDEX_PATH, "student_index.json")

    if args.test:
        if not args.nisn or not args.dob:
            print("[ERROR] --test requires both --nisn and --dob", file=sys.stderr)
            sys.exit(1)
        test_decryption(enc_map, idx_map, args.nisn.strip(), args.dob.strip())
    else:
        show_summary(enc_map, idx_map)


if __name__ == "__main__":
    main()
