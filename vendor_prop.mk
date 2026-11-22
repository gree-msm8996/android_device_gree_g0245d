#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Fingerprint: Goodix GF816M
PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware.fingerprint=gfp

# Speaker amp: TFA9890 behind Tasha
PRODUCT_PROPERTY_OVERRIDES += \
    ro.config.tfa98xx=1
