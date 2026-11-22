/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "android.hardware.ir@1.0-service.g0245d"

#include <android-base/logging.h>
#include <hidl/HidlTransportSupport.h>

#include "ConsumerIr.h"

using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::ir::V1_0::IConsumerIr;
using android::hardware::ir::V1_0::implementation::ConsumerIr;

int main() {
    android::sp<IConsumerIr> service = new ConsumerIr();

    configureRpcThreadpool(1, true /* callerWillJoin */);
    android::status_t status = service->registerAsService();
    if (status != android::OK) {
        LOG(ERROR) << "Cannot register G0245D Consumer IR HAL: " << status;
        return 1;
    }

    LOG(INFO) << "G0245D Consumer IR HAL ready";
    joinRpcThreadpool();
    return 1;
}
