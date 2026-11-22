#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Get non-open-source specific aspects
$(call inherit-product, vendor/gree/g0245d/g0245d-vendor.mk)

# Inherit from gree msm8996-common
$(call inherit-product, device/gree/msm8996-common/msm8996.mk)

# Overlays
DEVICE_PACKAGE_OVERLAYS += \
    $(LOCAL_PATH)/overlay

# First-stage fstab: init reads it from the boot ramdisk before /system exists.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/fstab.ramdisk:$(TARGET_COPY_OUT_RAMDISK)/fstab.qcom

# Device init: userspace glue proven working on G0245D (display handoff, USB
# gadget, sensors daemon bring-up, fingerprint dev node). vendor/ueventd.rc is
# installed by msm8996-common's ueventd.qcom.rc module.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/etc/init.g0245d.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/init.g0245d.rc

# Audio: G0245D platform info and Tasha mixer with TFA9890 speaker routing,
# values proven working on device (sound card msm8996-tasha-mtp-snd-card).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/audio/audio_platform_info.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_platform_info.xml \
    $(LOCAL_PATH)/audio/mixer_paths_tasha.xml:$(TARGET_COPY_OUT_VENDOR)/etc/mixer_paths_tasha.xml

# ACDB calibration blocks, TFA9890 container, fingerprint/vendor firmware
# and all other device-specific blobs are declared in
# vendor/gree/g0245d (see extract-files.sh + proprietary-files.txt).

# Camera: mm-qcamera-daemon is an Android-6 (32-bit) blob that double-destroys
# a pthread mutex on the CAM_stopisp thread.  Upstream used the LD_PRELOAD shim
# libshim_mutex.so (rc: mm-qcamera-daemon) to intercept pthread_mutex_destroy.
# Under SELinux enforcing, init does a domain transition when starting the
# daemon, which sets AT_SECURE=1; bionic then *ignores* LD_PRELOAD entirely, so
# the shim is never loaded and the daemon aborts with FORTIFY / SIGABRT on a
# cold camera open.  (In permissive AT_SECURE stays 0, hiding the bug.)
# Fix: this copy of the daemon has libshim_mutex.so added as a DT_NEEDED entry.
# DT_NEEDED is honoured even with AT_SECURE=1, so the shim is always loaded and
# the mutex interposition works in enforcing.  The stock declaration in
# vendor/gree/msm8996-common/msm8996-common-vendor.mk is removed so this patched
# copy is the sole source for /vendor/bin/mm-qcamera-daemon.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/camera/mm-qcamera-daemon:$(TARGET_COPY_OUT_VENDOR)/bin/mm-qcamera-daemon

# Input
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/keylayout/gpio-keys.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/gpio-keys.kl \
    $(LOCAL_PATH)/keylayout/tiny4412-key.kl:$(TARGET_COPY_OUT_VENDOR)/usr/keylayout/tiny4412-key.kl

# Fingerprint: Goodix GF816M via gx_fpd daemon + legacy fingerprint HAL.
# ALL fingerprint fix content lives in this device tree (fingerprint/):
#   - reverse-patched stock blobs (fingerprint.qcom.so, libfphal.so)
#   - binder_bridge built from source via fingerprint/Android.bp (no prebuilt .so)
#     and linked into fingerprint.qcom.so via DT_NEEDED; a service rc LD_PRELOAD
#     is ineffective once the HAL is launched through init (AT_SECURE=1).
# The vendor tree is kept stock: its two fingerprint blob declarations are
# removed in vendor/gree/g0245d/g0245d-vendor.mk, so the patched copies below
# are the sole source for those destinations.

PRODUCT_PACKAGES += \
    android.hardware.biometrics.fingerprint@2.0-service \
    binder_bridge

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/fingerprint/fingerprint.qcom.so:$(TARGET_COPY_OUT_VENDOR)/lib64/hw/fingerprint.qcom.so \
    $(LOCAL_PATH)/fingerprint/libfphal.so:$(TARGET_COPY_OUT_VENDOR)/lib64/libfphal.so

# Telephony: the Qualcomm modem stack (QCRIL + QMI + qmuxd/netmgrd/DSI) lives
# in msm8996-common/radio now; the blobs are installed by the common vendor
# makefile. rild/ holds the older patched QCRIL as history, not installed.
-include device/gree/msm8996-common/radio/radio.mk

# IR blaster: hidl service that drives the Raon controller behind
# /dev/remote_ctrl_dev. The service carries its own VINTF fragment, so the
# device manifest does not need a second IConsumerIr declaration.
PRODUCT_PACKAGES += \
    android.hardware.ir@1.0-service.g0245d

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.consumerir.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.consumerir.xml

# Vendor properties
-include $(LOCAL_PATH)/vendor_prop.mk
