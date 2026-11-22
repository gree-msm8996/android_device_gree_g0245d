#!/usr/bin/env python3
"""Patch libril-qc-qmi-1.so (xiaomi msm8996 blob) to skip xiaomi's CMCC-custom
OEM-NV probe, which deadlocks rild init on G0245D.

Background (2026-11-21):
  qcril_qmi_nas_init() calls xiaomi_qcril_check_cmcc_cust() at vaddr 0x33b3c0.
  That helper goes through read_oem_nv_internal() -> qmi_nv_read_oem_item()
  (libqminvapi.so) and blocks forever in pthread_cond_wait when the modem's
  QMI-NV service never answers.  Because this happens on the main qcril worker
  thread, rild never finishes init: every RIL_REQUEST_RADIO_POWER stays in
  'SETTING_OP_MODE' and the framework never gets a SIM.

Patch: replace the single `bl 0x4ef900` with NOP (0xd503201f).

Usage: python3 patch_ril_cmcc.py <input.so> <output.so>
"""
import sys

VADDR_CALL = 0x33B3C4          # address objdump reports for the bl
VADDR_DELTA = 0xB6000          # file_offset = vaddr - VADDR_DELTA
ORIG = bytes.fromhex("4fd10694")   # bl 0x4ef900
NOP = bytes.fromhex("1f2003d5")    # nop


def main():
    src, dst = sys.argv[1], sys.argv[2]
    data = bytearray(open(src, "rb").read())
    off = VADDR_CALL - VADDR_DELTA
    cur = bytes(data[off:off + 4])
    if cur == NOP:
        print("already patched")
    elif cur != ORIG:
        raise SystemExit("unexpected bytes at 0x%x: %s" % (off, cur.hex()))
    else:
        data[off:off + 4] = NOP
        print("patched bl->nop at file offset 0x%x" % off)
    open(dst, "wb").write(data)


if __name__ == "__main__":
    main()
