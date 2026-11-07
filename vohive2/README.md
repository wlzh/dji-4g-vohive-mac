# VoHive 2 预发布产物（未出正式版）

VoHive 2（上游 [iniwex5](https://github.com/iniwex5/vohive-release) 的新一代版本）**已开始预发布**，本目录内置当前开发版 **`0.1.2+gdb2d78a8`**（musl 静态编译、UPX 压缩的单文件二进制）。**正式版尚未发布**，以下产物仅供尝鲜与测试。

- **在线前端演示**（演示数据 · 不连接后端，刷新即重置）：<https://cool-glitter-88a5.iniwex.workers.dev/>
- 完整部署教程（v1）与项目说明见[仓库首页](../README.md)

## 目录内容

| 文件 | 说明 |
|---|---|
| `vohive2-linux-amd64-musl-0.1.2+gdb2d78a8-upx` | Linux **x86_64** 预编译二进制（Intel Mac 的 UTM VM / 普通 x86 Linux） |
| `vohive2-linux-arm64-musl-0.1.2+gdb2d78a8-upx` | Linux **arm64** 预编译二进制（Apple Silicon 的 UTM VM / 树莓派等 ARM 板） |
| `screenshot-dashboard.png` | v2 前端预览截图（首屏：设备总览 / 主链路信号与 IMS / 实时流量） |
| `screenshot-full.png` | v2 前端预览截图（完整长图：蜂窝网络信息 / SIM 与 eSIM / 流量统计） |

## SHA-256

```text
8250455874665e2c08d72c0b0478643ced928eecec8e9a60aa33ed210e3240e9  vohive2-linux-amd64-musl-0.1.2+gdb2d78a8-upx
411026c18e0264e180cd42afc0f9be33e9d20efc85dafb2b4d8a4e29406f3ac8  vohive2-linux-arm64-musl-0.1.2+gdb2d78a8-upx
```

## 运行

musl 静态编译，无运行时依赖，任意 Linux 发行版（含本仓库 UTM 方案里的 Ubuntu VM）可直接运行：

```bash
chmod +x vohive2-linux-arm64-musl-0.1.2+gdb2d78a8-upx
./vohive2-linux-arm64-musl-0.1.2+gdb2d78a8-upx
```

> ⚠️ **预发布开发版**：CLI 参数、配置格式、Web 端口等均以正式版发布说明为准，可能随时变化，不建议用于生产环境。
