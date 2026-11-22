# camera 目录 blobs 来源与重做方法

## mm-qcamera-daemon

最终文件：`mm-qcamera-daemon`，md5 `baa2d9a507abd8c9ab37f8836d5ecc73`。

输入基线：G0245D stock Android 6 daemon，
`work/stocklibs/mm-qcamera-daemon` / `work/stock_hal/mm-qcamera-daemon`，
md5 `ddd953e833531eb42e551b3911d18e0b`。

修改方法：用 LIEF 给 ELF 增加一条 `DT_NEEDED=libshim_mutex.so`。
不要只依赖 `init.g0245d.rc` 的 `setenv LD_PRELOAD libshim_mutex.so`：
SELinux enforcing 下 init 域转换设置 `AT_SECURE=1`，bionic 会忽略 `LD_PRELOAD`，
导致 `pthread_mutex_destroy` 双释放触发 FORTIFY/SIGABRT，冷启动相机失败。
`DT_NEEDED` 在 `AT_SECURE=1` 下仍生效。

验证：

```bash
readelf -d device/gree/g0245d/camera/mm-qcamera-daemon | grep libshim_mutex
```

必须看到 `(NEEDED) libshim_mutex.so`。

shim 的二进制仍由 vendor/gree 提供：
`msm8996-common/proprietary/vendor/lib/libshim_mutex.so`，
源码参考在 `device/gree/msm8996-common/camera_shims/libshim_mutex.c`。
vendor 中原来的 stock daemon 声明已删除，因此这里的文件是
`/vendor/bin/mm-qcamera-daemon` 的唯一来源。
