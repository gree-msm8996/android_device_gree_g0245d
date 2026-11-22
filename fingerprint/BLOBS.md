# fingerprint 目录 blobs 来源与重做方法

本目录中的 blobs 全部来自 G0245D/CM13 stock 或早期 vendor 树，修改只在本设备树内保存；
vendor/gree 中只保留 stock 副本，必须由 `device.mk` 保证这里的文件胜出。
以下记录用于以后从 stock 重新加工，不依赖当前二进制。

## fingerprint.qcom.so

最终文件：`fingerprint.qcom.so`，md5 `baf68a5d9abb255a4451d0ce88cd44db`。

输入基线：
- 早期 vendor 树 `vendor/gree/g0245d/proprietary/vendor/lib64/hw/fingerprint.qcom.so`
  （历史 commit `0916601`），md5 `55c20cec8f98b44912271bf73599b7d5`。
  该基线已经带有 DT_NEEDED 修复（NEEDED 中不含 `libandroid_runtime.so`），保留。
- stock CM13 参考 `work/stock-baseline/fingerprint.default.so`，
  md5 `a2a5ef1d445a9187d41021634b386535`。

按顺序应用以下修改：

1. `fingerprint_cancel` @ `0x6790..0x67df`，20 条 AArch64 指令，源码：
   `work/fp_tool/fp_cancel_patch.s`。
   作用：取消时主动调用 `goodix_sensor_fp_cancel`、`setListenerState` 并发送
   `send_fp_error(w3=5, FINGERPRINT_ERROR_CANCELED)`，解决 LOS 18.1 两段式录入卡住。
   得到 md5 `f15549a8fffad6c4bd0963c0be12db9b`。

2. @ `0x8d30` 把调试残留的 4 字节 `56 ff ff 17` 恢复为 stock CM13 的
   `c0 03 5f d6`（`RET`），参考 `work/stock-baseline/fingerprint.default.so`。

3. 重写 `fingerprint_enumerate` stub @ `0x62ec..0x6328`（60 字节），源码/二进制：
   `work/fp_tool/fp_enumerate_patch.s` / `fp_enumerate_patch.bin`。
   作用：从 `[dev+672]` 读取模板数，从 `[dev+372+i*4]` 读取真实 fingerId，写回
   `*max_size`，避免 framework 把 100 个空 fid=0 当作模板并删除真实模板。
   得到 md5 `a5ef66ac5492b3770bc7730454e45ed0`。

4. 锁屏图标修复：
   - @ `0x6328`（24 字节）在 `get_auth_id` 入口 hook
     `loadFingerPrintPlatformDataIfNeed`（BL `0x694c`），再保留原语义；
   - @ `0x6304`（4 字节）把 fill loop 的 `add x0,x0,#0x174` 改为 `#0x178`，
     从真实 fingerId 数组下标 1 开始读取。
   得到 md5 `8fba8b0806814a7240154ac1bcd38bff`。

5. v4 空枚举补丁 @ `0x62f0..0x62fc`（脚本 `work/fp_tool/make_v4.py`）：
   - `0x62f0`: `cmp w4, #0`（`0x7100009f`）
   - `0x62f4`: `b.ne #0x62fc`（`0x54000041`）
   - `0x62f8`: `mov w4, #1`（`0x52800024`）
   作用：HAL 没有模板时返回一个 fid=0 占位，使 HIDL 发出
   `onEnumerate(remaining=0)`，否则 EnumerateClient 永久卡住、录入不启动。

6. 用 LIEF 给 blob 增加 `DT_NEEDED=binder_bridge.so`。`AT_SECURE=1` 下 bionic
   忽略 rc 中的 `LD_PRELOAD`，但 `DT_NEEDED` 仍生效，这样 constructor 才能打开
   `/dev/binder` 并连接 `gx_fpd` 的 `goodix.fp` 服务。
   验证：`readelf -d fingerprint.qcom.so | grep binder_bridge`。

最终 md5 必须为 `baf68a5d9abb255a4451d0ce88cd44db`。

## libfphal.so

最终文件：`libfphal.so`，md5 `5ccaf02dd20a263ae294580a7baf9573`，
与 `work/stock-baseline/libfphal.so` 字节一致，未做额外裁剪。

早期 vendor 同名文件 md5 `e7360d46617c89e473c27a4685fed487`，在
`0x5ce4..0x5cef` 有 12 字节被破坏：

```text
vendor: 20 00 80 52 80 02 00 39 51 00 00 14
stock : 80 02 40 39 1f 04 00 71 20 0a 00 54
```

重做方法：直接复制 CM13 stock `libfphal.so`，或把上述 12 字节恢复为 stock 值。

## vendor 侧 gx_fpd / libfp_client / libfpservice（2026-11-22 会话32：**不可换 stock**）

结论先写：这三件 + 本目录的 HAL 是一个 **ABI 闭环**，只能同源。

实验：把 stock 6.0.1 的 `gx_fpd` / `libfp_client.so` / `libfpservice.so` 换上去，
并补上 stock `/lib64/libunwind.so`（gx_fpd 的 DT_NEEDED 需要），开机后 HAL 反复自杀：

```
__stack_chk_fail in android::BpFpService::connect()   <- libfp_client.so
  <- android::Fp::connect(FpClientType)               <- libfp_client.so
  <- goodix_sensor_init()                             <- fingerprint.qcom.so
  <- goodix_sensor_set_active_group()                 <- fingerprint.qcom.so
  <- BiometricsFingerprint::setActiveGroup()
dumpsys fingerprint: prints[].count=0, "HAL deaths since last reboot: 8"
```

原因：本目录的 `fingerprint.qcom.so` 基线（md5 `55c20cec...`）就是 **G0215D 的
`/system/vendor/lib64/hw/fingerprint.qcom.so`**，它给 `Fp::connect` 传的 client type
stock 6.0.1 的 `libfp_client` 不认识 → 越界写，canary 炸。stock 6.0.1 里根本没有
`fingerprint.qcom.so`，只有 `fingerprint.default.so`（md5 `a2a5ef1d...`）。
所以**四件运行时 blob + HAL 必须同一份构建**，不能只换其中几件。

现状（与改造前一致，已实机验证可用）：

| 文件 | sha1 | 来源 |
| --- | --- | --- |
| `vendor/bin/gx_fpd` | `fc99a7caf09464a0a4a59fc2f0e66b2cebc4bfd8` | G0215D 镜像 |
| `vendor/lib64/libfp_client.so` | `ffd0ec58530fc2d8268233fa99aeccfc3bd9c138` | G0215D 镜像 |
| `vendor/lib64/libfpservice.so` | `bf1fcf2de0d6863361d4b5a5e840636247ed1a4e` | G0215D 镜像 |
| `vendor/lib64/libfpalgorithm.so` | `6aaa002bd1046fa3424bb99b3c8bd506ad99e3cb` | **与 stock 字节相同** |

`gx_fpd` 的 dynstr 里 `libbacktrace.so` / `libunwind.so` 两个 NEEDED 字符串在
**G0215D 镜像里就已经**被改写成 `libc.so`（本系统 /system/lib64 没有
`libunwind.so`），不是本项目打的补丁。

要彻底去掉 G0215D 依赖，只能以 stock `fingerprint.default.so` 为新基线，把本文上半部分
（cancel / RET / enumerate / auth_id / v4 空枚举 / binder_bridge DT_NEEDED）整套重新
逆向一遍 —— 属于独立任务，涉及真机按压验证，不能顺手做。
