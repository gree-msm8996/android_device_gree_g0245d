/*
 * Copyright (C) 2026 The LineageOS Project
 * SPDX-License-Identifier: Apache-2.0
 *
 * HIDL Consumer IR implementation for the Gree G0245D Raon controller.
 *
 * The Raon chip is reached through a raw I2C passthrough node.  A transmit
 * request is encoded as a small binary program: a 24-bit carrier frequency
 * followed by one 16-bit carrier-cycle count for every mark/space interval in
 * the Android pattern.  The program is split into frames with a sequence
 * number, a length byte and a checksum.  This file implements that wire
 * format directly for G0245D; it is not a libhardware consumerir module.
 */

#define LOG_TAG "ConsumerIrService.g0245d"

#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <vector>

#include <fcntl.h>
#include <unistd.h>

#include <android-base/logging.h>

#include "ConsumerIr.h"

namespace android {
namespace hardware {
namespace ir {
namespace V1_0 {
namespace implementation {

namespace {

constexpr const char* kRaonDevice = "/dev/remote_ctrl_dev";
constexpr size_t kMaxFramePayload = 250;
constexpr int64_t kMaxTransmitUs = 2000000;

constexpr int32_t kCarrierTable[] = {
    30000, 33000, 36000, 38000, 40000, 56000,
};

hidl_vec<ConsumerIrFreqRange> supportedRanges{
    ConsumerIrFreqRange{30000, 30000},
    ConsumerIrFreqRange{33000, 33000},
    ConsumerIrFreqRange{36000, 36000},
    ConsumerIrFreqRange{38000, 38000},
    ConsumerIrFreqRange{40000, 40000},
    ConsumerIrFreqRange{56000, 56000},
};

int32_t nearestCarrier(int32_t requested) {
    int32_t best = kCarrierTable[0];
    int32_t bestDistance = requested > best ? requested - best : best - requested;

    for (int32_t candidate : kCarrierTable) {
        int32_t distance = requested > candidate ? requested - candidate
                                                 : candidate - requested;
        if (distance < bestDistance) {
            best = candidate;
            bestDistance = distance;
        }
    }
    return best;
}

void appendBigEndian16(std::vector<uint8_t>* bytes, uint16_t value) {
    bytes->push_back(static_cast<uint8_t>(value >> 8));
    bytes->push_back(static_cast<uint8_t>(value & 0xff));
}

bool writeFully(int fd, const uint8_t* bytes, size_t length) {
    size_t written = 0;

    while (written < length) {
        ssize_t result = write(fd, bytes + written, length - written);
        if (result < 0) {
            if (errno == EINTR) {
                continue;
            }
            LOG(ERROR) << "Raon IR write failed: " << strerror(errno);
            return false;
        }
        if (result == 0) {
            LOG(ERROR) << "Raon IR write returned zero bytes";
            return false;
        }
        written += static_cast<size_t>(result);
    }
    return true;
}

bool sendFrame(int fd, uint8_t sequence, const uint8_t* payload,
               size_t payloadLength) {
    if (payloadLength > kMaxFramePayload) {
        LOG(ERROR) << "Raon IR frame too large: " << payloadLength;
        return false;
    }

    std::vector<uint8_t> frame;
    frame.reserve(payloadLength + 4);
    frame.push_back(sequence);
    frame.push_back(static_cast<uint8_t>(payloadLength + 2));

    uint32_t checksum = static_cast<uint32_t>(sequence) + frame[1];
    for (size_t i = 0; i < payloadLength; ++i) {
        frame.push_back(payload[i]);
        checksum += payload[i];
    }
    appendBigEndian16(&frame, static_cast<uint16_t>(checksum));

    return writeFully(fd, frame.data(), frame.size());
}

bool encodePattern(const hidl_vec<int32_t>& pattern, int32_t carrier,
                   std::vector<uint8_t>* program, int64_t* totalUs) {
    program->clear();
    program->reserve(4 + pattern.size() * 2);

    program->push_back(0);
    program->push_back(static_cast<uint8_t>((carrier >> 16) & 0xff));
    program->push_back(static_cast<uint8_t>((carrier >> 8) & 0xff));
    program->push_back(static_cast<uint8_t>(carrier & 0xff));

    *totalUs = 0;
    for (size_t i = 0; i < pattern.size(); ++i) {
        int32_t micros = pattern[i];
        if (micros <= 0) {
            LOG(ERROR) << "Invalid IR interval at index " << i << ": " << micros;
            return false;
        }

        *totalUs += micros;
        uint64_t cycles = static_cast<uint64_t>(micros) *
                          static_cast<uint64_t>(carrier) / 1000000ULL;
        cycles = std::max<uint64_t>(cycles, 1);
        cycles = std::min<uint64_t>(cycles, 65535);
        appendBigEndian16(program, static_cast<uint16_t>(cycles));
    }
    return true;
}

}  // namespace

Return<bool> ConsumerIr::transmit(int32_t carrierFreq,
                                  const hidl_vec<int32_t>& pattern) {
    if (pattern.size() == 0 || carrierFreq <= 0) {
        LOG(ERROR) << "Empty IR pattern or invalid carrier " << carrierFreq;
        return false;
    }

    int32_t carrier = nearestCarrier(carrierFreq);
    std::vector<uint8_t> program;
    int64_t totalUs = 0;
    if (!encodePattern(pattern, carrier, &program, &totalUs)) {
        return false;
    }

    int fd = open(kRaonDevice, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        LOG(ERROR) << "Cannot open " << kRaonDevice << ": " << strerror(errno);
        return false;
    }

    size_t offset = 0;
    size_t lastChunk = 0;
    uint8_t sequence = 0;
    while (offset < program.size()) {
        size_t chunk = std::min(kMaxFramePayload, program.size() - offset);
        if (!sendFrame(fd, sequence, program.data() + offset, chunk)) {
            close(fd);
            return false;
        }
        offset += chunk;
        lastChunk = chunk;
        ++sequence;
    }

    // A full final frame needs an explicit zero-length terminator.
    if (lastChunk == kMaxFramePayload &&
        !sendFrame(fd, sequence, nullptr, 0)) {
        close(fd);
        return false;
    }
    close(fd);

    LOG(INFO) << "Sent IR pattern: requested " << carrierFreq << " Hz, using "
              << carrier << " Hz, " << pattern.size() << " intervals";

    // The controller raises busy until the whole burst has been played out.
    totalUs = std::min(totalUs, kMaxTransmitUs);
    usleep(static_cast<useconds_t>(totalUs + 80000));
    return true;
}

Return<void> ConsumerIr::getCarrierFreqs(getCarrierFreqs_cb _hidl_cb) {
    _hidl_cb(true, supportedRanges);
    return Void();
}

}  // namespace implementation
}  // namespace V1_0
}  // namespace ir
}  // namespace hardware
}  // namespace android
