#!/bin/bash
#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# If we're being sourced by the common script that we called,
# stop right here. No need to go down the rabbit hole.
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    return
fi

set -e

export DEVICE=g0245d
export DEVICE_COMMON=msm8996-common
export VENDOR=gree

"./../../${VENDOR}/${DEVICE_COMMON}/extract-files.sh" "$@"
