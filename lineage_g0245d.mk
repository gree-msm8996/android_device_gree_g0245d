#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from g0245d device
$(call inherit-product, device/gree/g0245d/device.mk)

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Device identifier. This must come after all inclusions.
PRODUCT_NAME := lineage_g0245d
PRODUCT_DEVICE := g0245d
PRODUCT_BRAND := Gree
PRODUCT_MODEL := G0245D
PRODUCT_MANUFACTURER := Gree

# Stock identity: G0245D_HALO_1.2.4_K2_Stable (Android 6.0.1, 2019-01-13),
# verified against stock /system/build.prop (ro.build.fingerprint).
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME="G0245D" \
    PRIVATE_BUILD_DESC="G0245D-user 6.0.1 MMB29M 5b20332 dev-keys"

BUILD_FINGERPRINT := "GREE/G0245D/G0245D:6.0.1/MMB29M/5b20332:user/dev-keys"

TARGET_VENDOR := gree
