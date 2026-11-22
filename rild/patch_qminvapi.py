#!/usr/bin/env python3
"""Patch libqminvapi.so (xiaomi msm8996 blob) so the NV reads fail fast.

Why (2026-11-21, G0245D):
  The xiaomi QMI RIL calls libqminvapi at rild init (xiaomi_qcril_check_cmcc_cust,
  get_sno).  Every helper in this library first asks xiaomi_qmi_nv_get_service_object
  for a xiaomi-private QMI service, then blocks in pthread_cond_wait until that
  service shows up.  The Gree modem firmware never publishes it, so the wait never
  returns and rild never finishes initialisation -> no radio, no SIM.

  See debuggerd stacks in work/ (ril_log_boot4/5, ROM_HANDOFF session 27).

Patch: entry of each qmi_nv_read_* OEM/serial helper becomes
        mov w0, #-1 ; ret          (fail fast, callers handle the error)
Band/LTE/RF NV reads are intentionally left untouched.

Usage: python3 patch_qminvapi.py <in.so> <out.so>
"""
import sys

# name -> vaddr (== file offset for this library)
TARGETS = {
    "qmi_nv_read_wlan_mac": 0x1550,
    "qmi_nv_read_mac_imp": 0x1584,
    "qmi_nv_read_bd_addr": 0x178C,
    "qmi_nv_read_serial_number": 0x17C0,
    "qmi_nv_read_phone_serial_number": 0x17F4,
    "qmi_nv_read_oem_item_2": 0x1828,
    "qmi_nv_read_oem_item_3": 0x185C,
    "qmi_nv_read_oem_item": 0x1890,
}

STUB = bytes.fromhex("00008012" "c0035fd6")   # mov w0, #-1 ; ret


def main():
    src, dst = sys.argv[1], sys.argv[2]
    data = bytearray(open(src, "rb").read())
    for name, off in TARGETS.items():
        if bytes(data[off:off + 8]) == STUB:
            print("%-32s already patched" % name)
            continue
        data[off:off + 8] = STUB
        print("%-32s stubbed at 0x%x" % (name, off))
    open(dst, "wb").write(data)


if __name__ == "__main__":
    main()
