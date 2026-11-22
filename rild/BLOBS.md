# rild 目录 blobs 来源与重做方法

G0245D 的 QMI RIL 使用 xiaomi msm8996-common 的 blobs（`vendor/gree/msm8996-common`）。
这两个 blob 里的小米私有逻辑在本机 modem 上会**永久阻塞 rild 初始化**，导致
`RIL_REQUEST_RADIO_POWER` 永远停在 `SETTING_OP_MODE`、SIM 永远 ABSENT。
本目录保存打过补丁的最终产物，并由 `device.mk` 安装；`vendor/gree` 保持 xiaomi 原样
（相应声明已从 `msm8996-common-vendor.mk` 删除，避免 PRODUCT_COPY_FILES 去重覆盖）。

## 症状与定位（2026-11-21）

- 插卡无反应，`gsm.sim.state=,ABSENT`，IMEI/baseband 正常，无 SELinux 拒绝。
- `ril_log` 中 token id 2（开机 RADIO_POWER off）一直挂在 `SETTING_OP_MODE`，
  后续 `RADIO_POWER on` 被 flow control 阻塞 → modem 永远 LPM。
- `debuggerd -b <rild>` 抓到主工作线程卡在：

```
#03 libqminvapi.so (qmi_nv_read_oem_item+208)          -> pthread_cond_wait
#04 libril-qc-qmi-1.so (read_oem_nv_internal+544)
#05 libril-qc-qmi-1.so (xiaomi_qcril_check_cmcc_cust+88)
#06 libril-qc-qmi-1.so (qcril_qmi_nas_init+488)
```

  打完上面的点后又卡在 `get_sno -> qmi_nv_read_serial_number -> qmi_nv_read_mac_imp`。

- 根因：`libqminvapi.so` 每个 `qmi_nv_read_*` 都先用
  `xiaomi_qmi_nv_get_service_object_internal_v01()` 取一个**小米私有 QMI 服务**，
  再用 `qmi_client_notifier_init` + `pthread_cond_wait` 死等该服务出现。
  Gree 的 modem 固件（2018-08-24，`/vendor/firmware_mnt/image/modem.b*`）不发布该服务，
  等待永不返回，且库内无超时 → rild 初始化死锁。

## libril-qc-qmi-1.so

- 最终文件：`libril-qc-qmi-1.so`，md5 `38c196a3cb6498c4eef0ac71b67611c5`。
- 输入基线：`vendor/gree/msm8996-common/proprietary/vendor/lib64/libril-qc-qmi-1.so`
  （与 `vendor/xiaomi/msm8996-common` 同一文件），md5 `8711e22adc56bba1ce818e69800e2ae6`。
- 修改：vaddr `0x33b3c4`（文件偏移 `0x2853c4`，`file_off = vaddr - 0xb6000`）
  `bl 0x4ef900`（`xiaomi_qcril_check_cmcc_cust`）→ `nop`（`1f 20 03 d5`）。
  全库仅这一处调用。
- 重做：`python3 patch_ril_cmcc.py <基线.so> <输出.so>`

## libqminvapi.so

- 最终文件：`libqminvapi.so`，md5 `1f393ca3017727dfcad46f2be4ea0c4c`。
- 输入基线：`vendor/gree/msm8996-common/proprietary/vendor/lib64/libqminvapi.so`，
  md5 `07bada143c6704d9b9bd6a06d1fb29f5`。
- 修改：以下导出函数入口改为 `mov w0,#-1 ; ret`（`00 00 80 12 c0 03 5f d6`），
  即快速失败，让调用方走错误分支（这些值只用于小米定制的 CMCC/序列号/MAC 上报，
  与本机功能无关）：

  | 偏移 | 符号 |
  | --- | --- |
  | 0x1550 | qmi_nv_read_wlan_mac |
  | 0x1584 | qmi_nv_read_mac_imp |
  | 0x178c | qmi_nv_read_bd_addr |
  | 0x17c0 | qmi_nv_read_serial_number |
  | 0x17f4 | qmi_nv_read_phone_serial_number |
  | 0x1828 | qmi_nv_read_oem_item_2 |
  | 0x185c | qmi_nv_read_oem_item_3 |
  | 0x1890 | qmi_nv_read_oem_item |

  band / LTE BC / RF BC / aagps 的 NV 读写**未改动**（涉及射频配置）。
- 重做：`python3 patch_qminvapi.py <基线.so> <输出.so>`

## 实机验证（2026-11-21，SELinux Enforcing）

- 打补丁后开机：`telephony ONLINE | card UP | modem ONLINE`，
  `RIL_REQUEST_RADIO_POWER (23) Complete --- RIL [RID 0, Token id 464, Success, Len 0]`。
- 冷启动必弹 SIM PIN：`gsm.sim.state=PIN_REQUIRED,ABSENT`，`input text 999188` +
  Enter 后 `LOADED,ABSENT`、`gsm.sim.operator.numeric=46001`、
  `gsm.sim.operator.alpha=China Unicom`，ICCID `8986012380169xxx9`、号码 `+86156968xxx8`。
  （两次冷启动复验一致：没有 PIN 就停在 `PIN_REQUIRED`。）
- 注册：`ro.telephony.default_network=20,20`（xiaomi 值，acq order 含 TD-SCDMA）时
  `nas_srv_status=LIMITED`、`gsm.network.type=Unknown`；改回 stock 的 `10,10` 并补
  `telephony.lteOnCdmaDevice=1` 后 `dumpsys telephony.registry` 出现
  `PS registrationState=HOME / accessNetworkTechnology=LTE`、`mDataConnectionState=2`，
  状态栏出现 LTE 信号格。
- 数据面：`RIL_REQUEST_SETUP_DATA_CALL Success`（APN `3gnet`），`rmnet_data0` 拿到运营商
  IP（`10.192.12.139/29`、`10.104.59.176/30` 两次不同），bearer LTE
  → SIM 鉴权、PDN 激活、用户面上行都通。

## 未解决（与读卡无关，独立问题）

- **下行完全收不到**：`rmnet_data0` TX 递增（112→120 包/session），RX 恒为 0；
  `/sys/kernel/debug/ipa/stats` `wan_rx=0`、`flow_enable=0`；
  `/sys/kernel/debug/ipa/rm_stats` `IPA_RM_RESOURCE_WWAN_0_PROD[700, Released]`、
  `All prod bandwidth: 0`。已排除的项：APN 正确、DNS 已下发（221.7.92.100/221.5.203.100）、
  `ip rule` 与 `table rmnet_data0` 的 `default via 10.x.x.x` 都在、
  原厂数据面属性（`ro.use_data_netmgrd`、`persist.rmnet.data.enable`、
  `persist.data.df.dl_mode/ul_mode/agg.*`）与 stock `build.prop` 逐条一致、netmgrd 在跑。
- **驻留不稳定**：现场小区极弱（`rsrp -104 → -117 dBm`、`rssnr -2`），约 20 分钟后
  `nas_srv_status=0`（NO_SERVICE），重启后 modem 连测量值都没有（`mLte` 全 0x7FFFFFFF），
  同一时间 WiFi 能扫到十几个 AP（排除屏蔽环境），mode pref 10 / 9 结果相同。
  需在信号良好处复测，才能区分「覆盖/天线」与「modem 侧驻留配置」。
  若下行仍为 0，下一步参考 `g0215d/docs/g0215d-phase-3.md` 的 7F 节：
  G0215D 是用原厂（Android 6）整套电话栈 + `/etc/data/*.xml` + `qcril.db` 跑通的，
  G0245D 的 `Stock/G0245D_HALO_1.2.4_K2_Stable.zip` 里有同样一份可直接取用。

## 注意

- 只改了 64 位库；`lib/libqminvapi.so`（32 位）未用，保持原样。
- `device/gree/msm8996-common/proprietary-files.txt` 的 RIL 段已加注释，说明这两个
  64 位库不再由 vendor 树安装（由本目录的补丁版经 `device.mk` 装），清单与
  `vendor/gree/msm8996-common/msm8996-common-vendor.mk` 一致。
- 这两处补丁不能靠 rc/属性绕过：死锁发生在 `qcril_qmi_nas_init()` 内部，早于任何
  RADIO_POWER 请求；`persist.vendor.radio.apm_mdm_not_pwdn` 等属性对此时序无效。
