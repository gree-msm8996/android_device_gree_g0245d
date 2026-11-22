/*
 * binder_bridge.so - DT_NEEDED constructor for fingerprint.qcom.so.
 * Forces android::ProcessState::self() so /dev/binder is opened for the
 * Goodix libfp_client.so -> gx_fpd ("goodix.fp") binder connection.
 * Device-side compatibility shim; no ROM source touched.
 */
#include <binder/ProcessState.h>
#include <utils/RefBase.h>
#include <android/log.h>

#define LOGI(...) __android_log_print(4, "fp-binder-bridge", __VA_ARGS__)
#define LOGE(...) __android_log_print(6, "fp-binder-bridge", __VA_ARGS__)

extern "C" __attribute__((constructor)) void fp_binder_bridge_init() {
    LOGI("step1 constructor entered");
    android::sp<android::ProcessState> ps = android::ProcessState::self();
    LOGI("step2 ProcessState::self()=%p", ps.get());
    if (ps.get() != NULL) {
        ps->startThreadPool();
        LOGI("step3 startThreadPool done");
    } else {
        LOGE("ProcessState::self() returned null");
    }
}
