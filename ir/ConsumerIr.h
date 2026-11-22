/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef G0245D_IR_CONSUMER_IR_H
#define G0245D_IR_CONSUMER_IR_H

#include <android/hardware/ir/1.0/IConsumerIr.h>
#include <hidl/Status.h>

namespace android {
namespace hardware {
namespace ir {
namespace V1_0 {
namespace implementation {

using ::android::hardware::Return;
using ::android::hardware::Void;
using ::android::hardware::hidl_vec;
using ::android::hardware::ir::V1_0::ConsumerIrFreqRange;
using ::android::hardware::ir::V1_0::IConsumerIr;

class ConsumerIr : public IConsumerIr {
  public:
    Return<bool> transmit(int32_t carrierFreq,
                          const hidl_vec<int32_t>& pattern) override;
    Return<void> getCarrierFreqs(getCarrierFreqs_cb _hidl_cb) override;
};

}  // namespace implementation
}  // namespace V1_0
}  // namespace ir
}  // namespace hardware
}  // namespace android

#endif  // G0245D_IR_CONSUMER_IR_H
