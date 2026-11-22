#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from common msm8996-common
-include device/gree/msm8996-common/BoardConfigCommon.mk

DEVICE_PATH := device/gree/g0245d

# Assert
TARGET_OTA_ASSERT_DEVICE := G0245D,g0245d

# Board
TARGET_BOARD_INFO_FILE := $(DEVICE_PATH)/board-info.txt

# HIDL
DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/manifest.xml

# Kernel: gree-adapted 4.4 tree, board selected via CONFIG_MACH_GREE_G0245D.# Image.gz-dtb appends exactly one DTB (g0245d-msm8996-v3-pmi8996-mtp).
# clang r383902 + LLVM_IAS=1 exactly as verified in los-finnal/KERNEL-BUILD-G0245D.md.
# Qualcomm sources #include <local headers>, so bare kbuild needs 15 extra -I
# paths (relative paths resolve against the build root, where make -C runs from).
# Kernel cmdline: exact copy of the verified boot-g0245d-audio-fix9.img
# cmdline. androidboot.boot_devices is REQUIRED for first_stage_mount to
# resolve /dev/block/by-name/system on this device; firmware_class.path
# points at the wlan/touch/amp firmware inside the system image.
#
# SELinux enforcing. G0245D-specific grants (fingerprint / IR device nodes)
# are in device/gree/g0245d/sepolicy; platform-wide and radio grants live in
# device/gree/msm8996-common/sepolicy. Note this cmdline only takes effect
# when boot.img is rebuilt from this BoardConfig.mk.
BOARD_KERNEL_CMDLINE := console=ttyHSL0,115200,n8 androidboot.console=ttyHSL0 androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x237 ehci-hcd.park=3 lpm_levels.sleep_disabled=1 cma=32M@0-0xffffffff androidboot.selinux=enforcing firmware_class.path=/system/etc/firmware androidboot.boot_devices=soc/624000.ufshc
# G0245D device-specific sepolicy (enforcing-mode allowances observed on the
# live system; crash_dump and flags_health_check read noise intentionally NOT
# covered - both are non-fatal under enforcing).
BOARD_SEPOLICY_DIRS += device/gree/g0245d/sepolicy
TARGET_KERNEL_CONFIG := vendor/gree/g0245d_defconfig
TARGET_KERNEL_CLANG_VERSION := r383902
GREE_KERNEL_INCS := drivers/bluetooth sound/soc/msm drivers/gpu/msm \
    drivers/media/platform/msm/camera_v2/common \
    drivers/media/platform/msm/camera_v2/isp \
    drivers/media/platform/msm/camera_v2/sensor/io \
    drivers/media/platform/msm/camera_v2/sensor \
    drivers/platform/msm/ipa/ipa_v2 drivers/platform/msm/mhi \
    drivers/soc/qcom drivers/video/fbdev/msm/msm_dba sound/soc/codecs
GREE_KERNEL_KCFLAGS := $(foreach d,$(GREE_KERNEL_INCS),-Ikernel/gree/msm8996/$(d))
TARGET_KERNEL_ADDITIONAL_FLAGS := LLVM_IAS=1 KCFLAGS="$(GREE_KERNEL_KCFLAGS)"

# Partitions, measured on device 2026-11-16 (/proc/partitions):
# cache sda3 = 268435456 B, userdata sda9 = 59212771328 B, system sde18 = 3221225472 B.
BOARD_CACHEIMAGE_PARTITION_SIZE := 268435456
BOARD_USERDATAIMAGE_PARTITION_SIZE := 59212771328

# G0245D has no vendor/cust partition: system-as-vendor. Clear the
# msm8996-common vendor image flags so no vendor.img is built; vendor files
# install into system/vendor (TARGET_COPY_OUT_VENDOR falls back to it).
BOARD_VENDORIMAGE_PARTITION_SIZE :=
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE :=

# Inherit from the proprietary version
-include vendor/gree/g0245d/BoardConfigVendor.mk
