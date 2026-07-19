# dji-4g-vohive-mac

> 在 Mac（Apple Silicon / Intel 通用）上，用 **UTM** 跑一个 Linux 虚拟机，把**大疆 4G 模块（1 代，本质移远 Quectel EG25-G）**的 USB 身份从大疆私有 `2ca3:4006` **永久改成移远 Quectel EC25 的 `2C7C:0125`**，并在该 Linux 里一键部署 **vohive** 短信/网络/eSIM 管理平台的全套步骤；**另附一套脚本，可把这颗模组一键切换成 Mac 的 4G 上网卡**（VoHive 保号 ↔ Mac 上网两种模式自由切换）。

## 视频教程

[![大疆 4G 模块在 Mac 上部署 VoHive 视频教程](https://img.youtube.com/vi/PZRkoggXFco/hqdefault.jpg)](https://youtu.be/PZRkoggXFco)

点击上方缩略图观看 YouTube 视频教程。

## 这个仓库做什么

- 给 Mac 用户提供一条**从零到能访问 vohive 后台**的可执行路径，无需另一台 Linux 真机。
- 解决大疆 4G 模块默认 VID/PID 是大疆私有、通用驱动不认的问题——通过发 AT 指令 `AT+QCFG="usbcfg",...` 把模块内部 USB 身份永久改写为移远 EC25，改一次终身有效。
- 同时覆盖 **Apple Silicon（arm64）** 和 **Intel（x86_64）** 两种 Mac：两者只有 ISO 和 VM 架构不同，VM 内所有操作完全一致。
- 包含 USB 直通、改身份后重新枚举断直通的坑及处理、验证清单、维护命令、方案选型对比。
- **支持把模组一键切换成 Mac 的 4G 上网卡**（VoHive 保号 ↔ Mac 上网两种模式自由切换，含三个自动化脚本），见下方「[让模组当 Mac 的 4G 上网卡](#让模组当-mac-的-4g-上网卡vohive--mac-切换)」章节。

## 项目依赖

本仓库本身只是一份操作手册（README），实际起作用的是上游 **[iniwex5/vohive-release](https://github.com/iniwex5/vohive-release)** 的发布资产。上游仓库仍在，但其最新 release `v1.5.5` **已无可下载的二进制 asset**（`vohive_v1.5.5_linux_<arch>` 实测 HTTP 404，release 的 assets 列表为空），在线安装脚本会在「下载二进制」那步失败。为此本仓库内置了两份可离线使用的资产：

| 内置包 | 内容 | 适用架构 | 是否联网 |
|---|---|---|---|
| `vohive-release-1.5.5.zip` | 在线安装脚本，运行时按架构到上游 release 拉取二进制 | arm64 + amd64 自动检测 | ❗ 上游二进制已 404，**当前会失败**，留作上游修复后使用 |
| `vohive-backup.tar.gz` | **离线恢复包**：内置 vohive 二进制（sha1 `ee16a5c0cd04505df43805fc81838f3e20b16aee`，与 backup `install.sh` 注释中记录的原版 sha1 一致）+ `install.sh` + `vohive.service` + `mcc-mnc-table.json` | **x86_64（Intel / 方案 B）** | ✅ 完全离线，**当前推荐路径** |

> ⚠️ 上游二进制 404 后，**Apple Silicon（方案 A，arm64）暂无内置离线二进制**：可继续试 `vohive-release-1.5.5.zip` 在线方式（等上游修复 asset），或自行备一份 `vohive_<ver>_linux_arm64` 后参照 `vohive-backup.tar.gz` 里的 `install.sh` 离线安装。Intel Mac（方案 B）直接用 `vohive-backup.tar.gz` 即可全程离线部署。

### [iniwex5/vohive-release](https://github.com/iniwex5/vohive-release)

**VoHive** 是面向高通 4G/5G 模组场景的一体化管理与代理平台，核心能力：

- 网页 / Bot 收发短信
- 多卡统一管理
- 实体 eSIM / eUICC 管理（加卡、切卡、删卡）
- 转量代理：支持 `SOCKS5/HTTP` 实例，按设备网卡强绑定出站
- TelegramBot / 飞书Bot / QQBot 远程控制
- 条件满足时启用 VoWiFi，并通过 `/vocall` 发起 VoWiFi 模拟外呼

**适用环境：** Linux（Debian/Ubuntu/树莓派/NAS）+ 移远 EC20CE / EM500Q / 高通 410 WIFI 板 / 各类高通 4G USB 模组（需 SIM 卡槽或带 SIM 卡槽的 USB 底板）。本仓库的作用正是让 Mac 用户通过 UTM Linux VM + USB 直通，把大疆 4G 模块变成 VoHive 能认的 Quectel EC25，从而跑起 VoHive。

**部署方式：** 下载本仓库内置的 `vohive-release-1.5.5.zip`，解压后执行其中的一键安装脚本（本仓库采用）或 Docker Compose。
```bash
curl -L -o vohive-release-1.5.5.zip \
  https://raw.githubusercontent.com/wlzh/dji-4g-vohive-mac/main/vohive-release-1.5.5.zip
unzip -o vohive-release-1.5.5.zip
cd vohive-release-1.5.5
bash install.sh
```
安装后：二进制 `/opt/vohive/bin/vohive`，配置 `/opt/vohive/config/config.yaml`，systemd 服务 `vohive`，后台 `http://<IP>:7575`（默认 `admin/admin`）。

**机器人常用命令：** `/list` 列设备、`/sms 设备ID` 看短信、`/send 设备ID 号码 内容` 发短信、`/rotate 设备ID` 换 IP、`/esim`、`/switch` 切 eSIM、`/vocall` VoWiFi 呼叫。

> ⚠️ VoHive 已禁止国内运营商卡发起 VoWiFi；VoWiFi 支持的运营商列表（CTE UK / giffgaff UK / Vodafone UK/DE / Telekom DE / O2 DE / T-Mobile US 等）见上游 README。

---

## 完整步骤

> 来源教程：<https://linux.do/t/topic/2486016>（标题：《大疆4G模块修改设备ID并一键部署vohive平台教程》）
>
> 本机为 M3 Pro，对应方案 A。两种芯片先看第 0.5 节选方案。

### 0. 为什么这么做（背景与约束）

- 大疆 4G 模块（1 代，约 30~40 元）**本质是移远 Quectel EG25-G**，但默认 USB VID/PID 是大疆私有的 `2ca3:4006`，通用驱动不认。
- 教程通过发 AT 指令把模块内部 USB 身份**永久改写**成移远 EC25 的 `2C7C:0125`，从而接入 vohive 平台。
- 教程全部命令是 **Linux 专用**（`modprobe option`、`/sys/bus/usb-serial/.../new_id`、`/dev/ttyUSB2`、`apt-get`、`lsusb`、systemd 服务），macOS 没有等价物，不能直接在 Mac 上照搬。
- vohive 官方 `install.sh` **只支持 Linux**（`os != linux` 直接退出），但**支持 arm64**（会下载 `vohive_<ver>_linux_arm64`，systemd 起服务）。所以在 M3 上跑 **arm64 Linux 虚拟机是原生速度**，不用 x86 模拟。
- **硬约束是 USB passthrough**：必须把大疆这个 USB 设备直通进 Linux VM。这排除了 OrbStack、Multipass、Docker Desktop（都不支持任意 USB 设备直通）。免费且支持 USB 直通的最佳选择是 **UTM**（基于 QEMU）。
- 改身份这步是**一次性的、改的是模块内部 NV，改一次终身有效**；改完模块插任何机器都是 Quectel EC25 身份。

### 0.5. 架构选择（按你的 Mac 芯片二选一）

先在 Mac 终端确认芯片：
```bash
uname -m
# 输出 arm64  → Apple Silicon，选 A
# 输出 x86_64 → Intel，选 B
```

| 项 | 方案 A：Apple Silicon | 方案 B：Intel Mac |
|---|---|---|
| VM 架构 | `aarch64`（原生 ARM 虚拟化） | `x86_64`（原生虚拟化，Hypervisor.framework） |
| Ubuntu ISO 文件名 | `ubuntu-24.04-live-server-arm64.iso` | `ubuntu-24.04-live-server-amd64.iso` |
| ISO 下载地址 | `https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-arm64.iso` | `https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso` |
| vohive 二进制 | 脚本自动下 `vohive_<ver>_linux_arm64` | 脚本自动下 `vohive_<ver>_linux_amd64` |
| UTM 虚拟化方式 | Virtualize（不要选 Emulate） | Virtualize |

> 后面第 2、3 步按你选的方案 A/B 取对应值；**第 4 步起（USB 直通、改身份、装 vohive、验证）两种方案完全一致，没有任何差别。**

### 1. 装 UTM（免费）

UTM 是 macOS 上基于 QEMU 的虚拟化前端，原生支持 Apple Silicon 的 ARM 虚拟化与 USB 设备直通。

```bash
brew install --cask utm
```

打开一次 UTM，确认能启动（macOS 可能要求在「系统设置 → 隐私与安全性」里允许运行）。

### 2. 下载 Ubuntu Server 24.04 ISO（按第 0.5 节选的方案）

**方案 A（Apple Silicon / arm64）：**
```bash
curl -L -o ~/Downloads/ubuntu-24.04-live-server-arm64.iso \
  https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-arm64.iso
```

**方案 B（Intel / amd64）：**
```bash
curl -L -o ~/Downloads/ubuntu-24.04-live-server-amd64.iso \
  https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso
```

下载完成后 `ls -lh ~/Downloads/ubuntu-24.04-live-server-*.iso` 确认大小约 2GB+。

### 3. 在 UTM 里创建并安装 Linux 虚拟机

1. 打开 UTM → 顶部 **＋** 新建虚拟机。
2. 选择 **Virtualize**（不要选 Emulate）——原生虚拟化，性能接近原生。
3. 架构按第 0.5 节选：**方案 A 选 `aarch64`**，**方案 B 选 `x86_64`**。
4. 系统类型选 **Debian/Ubuntu**。
5. 内存 **2 GB**、CPU **2 核**、磁盘 **20 GB**（跑 vohive 足够）。
6. 「CD/DVD」挂载第 2 步下载的 ISO。
7. 网络保留默认（NAT，UTM 会给 VM 分一个 192.168.x.x 的 DHCP 地址）。
8. 启动 VM，按 Ubuntu 安装流程走：
   - 语言/键盘默认即可
   - 安装类型选 Ubuntu Server（最小化，无桌面）
   - **务必勾选安装 OpenSSH server**（方便从 Mac 终端 ssh 进去操作）
   - 用户名/密码自行设置，记下来
9. 装完重启，拔掉 ISO（UTM 里弹出 CD）。

#### 从 Mac ssh 进 VM（推荐，后面命令都在这里跑）

在 VM 控制台里先看 IP：
```bash
ip a
```
拿到 `192.168.x.x` 后，在 Mac 终端：
```bash
ssh <ubuntu用户名>@192.168.x.x
```
后续所有命令都在这个 ssh 会话里执行。

### 4. 把大疆 4G 模块直通进 VM

1. 把大疆 4G 模块 USB 插到 Mac。
2. UTM → 选中该 VM → 设置 → **USB** 选项卡 → 勾选大疆设备（显示为 VID:PID `2ca3:4006`）做 passthrough。
3. 回到 VM（或 ssh），确认设备已进来：
```bash
lsusb
# 应能看到一行含 2ca3:4006
```
> 若 VM 里没装 `lsusb`：`sudo apt-get install usbutils -y`

### 5. 改大疆模块设备 ID（改成移远 EC25 身份）

在 VM 里依次执行（教程原样）：

```bash
# 0. 装 socat（发 AT 指令用）
sudo apt-get update && sudo apt-get install socat -y

# 1. 临时加载 option 驱动模块
sudo modprobe option

# 2. 把大疆当前识别码 2ca3:4006 写入 option 驱动，生成串口文件
echo 2ca3 4006 | sudo tee /sys/bus/usb-serial/drivers/option1/new_id

# 3. 通过 /dev/ttyUSB2 发 AT 指令，永久改 USB 身份为移远 2C7C:0125
echo 'AT+QCFG="usbcfg",0x2C7C,0x0125,1,1,1,1,1,0,0' | socat - /dev/ttyUSB2,crnl

# 4. 软重启模块使配置生效
echo 'AT+CFUN=1,1' | socat - /dev/ttyUSB2,crnl
```

等几秒，模块重新初始化后查看：
```bash
lsusb
# 应显示：2c7c:0125 Quectel Wireless Solutions Co., Ltd. EC25 LTE modem
```

#### ⚠️ 关键坑：USB 重新枚举会断开直通

`AT+CFUN=1,1` 让模块软重启，VID/PID 从 `2ca3:4006` 变成 `2c7c:0125`。如果 UTM 是按 VID/PID 绑定直通的，这一瞬间直通会断开，`lsusb` 在 VM 里可能短暂看不到设备。

处理方式：
- 在 UTM 里把直通规则改成绑定到新的 Quectel 设备 `2c7c:0125`，或绑定到**物理 USB 端口**（更稳，重新枚举不会丢）。
- 重新勾选一次直通，模块就永久留在 VM 里给 vohive 用。
- 改身份是一次性的；改完后这个模块插任何机器都是 Quectel EC25 身份。

### 6. 一键部署 vohive 平台

模块身份改完且直通稳定后，在 VM 里部署 vohive。两种方式选其一：

#### 方式一（推荐·离线）：内置 `vohive-backup.tar.gz`（仅 x86_64 / 方案 B）

适合 Intel Mac 建的 amd64 VM，**全程不联网**，规避上游二进制 404：

```bash
sudo apt-get update && sudo apt-get install -y wget
wget -O vohive-backup.tar.gz \
  https://raw.githubusercontent.com/wlzh/dji-4g-vohive-mac/main/vohive-backup.tar.gz
tar -xzf vohive-backup.tar.gz
cd vohive-backup
sudo bash install.sh
```
脚本会校验架构、把内置二进制 / 运营商表 / 默认配置 / systemd 单元一并部署到位，**不再联网下载二进制**。

#### 方式二（在线）：`vohive-release-1.5.5.zip`（arm64 / amd64 自动检测）

```bash
sudo apt-get update && sudo apt-get install -y unzip
curl -L -o vohive-release-1.5.5.zip \
  https://raw.githubusercontent.com/wlzh/dji-4g-vohive-mac/main/vohive-release-1.5.5.zip
unzip -o vohive-release-1.5.5.zip
cd vohive-release-1.5.5
bash install.sh
```
> ⚠️ 此方式在「下载二进制」那步依赖上游 `iniwex5/vohive-release` 的 release asset；**上游 v1.5.5 二进制已 404，当前大概率失败**，此时方案 B 请改用方式一，方案 A 需自备 arm64 二进制。

#### 部署结果（两方式一致）

- 二进制 → `/opt/vohive/bin/vohive`
- 配置 → `/opt/vohive/config/config.yaml`（默认 Web 账号 `admin / admin`）
- 注册 systemd 服务 `vohive.service` 并启动
- 数据/日志 → `/opt/vohive/data`、`/opt/vohive/logs`

#### 访问后台

从 Mac 浏览器打开：
```
http://<VM的IP>:7575
```
默认 `admin / admin`，**登录后立即改密码**。

### 7. 验证清单

- [ ] VM 里 `lsusb` 能看到 `2c7c:0125 Quectel ... EC25 LTE modem`
- [ ] VM 里 `systemctl status vohive` 显示 active (running)
- [ ] Mac 浏览器访问 `http://<VM-IP>:7575` 能出登录页
- [ ] 用 `admin/admin` 登录成功并改密
- [ ] vohive 后台能识别到 4G 模块、看到信号/短信等功能

### 8. 维护与可选操作

#### 更新 vohive
```bash
curl -L -o vohive-release-1.5.5.zip \
  https://raw.githubusercontent.com/wlzh/dji-4g-vohive-mac/main/vohive-release-1.5.5.zip
unzip -o vohive-release-1.5.5.zip
cd vohive-release-1.5.5
bash install.sh
```
脚本会自动备份旧二进制到 `/opt/vohive/bin/vohive.bak` 再覆盖。

#### 卸载 vohive
```bash
curl -L -o vohive-release-1.5.5.zip \
  https://raw.githubusercontent.com/wlzh/dji-4g-vohive-mac/main/vohive-release-1.5.5.zip
unzip -o vohive-release-1.5.5.zip
cd vohive-release-1.5.5
bash uninstall.sh
```

#### 不用 systemd 的环境（如容器/WSL，本方案用不到）
```bash
curl -L -o vohive-release-1.5.5.zip \
  https://raw.githubusercontent.com/wlzh/dji-4g-vohive-mac/main/vohive-release-1.5.5.zip
unzip -o vohive-release-1.5.5.zip
cd vohive-release-1.5.5
bash install.sh --no-systemd
# 手动启动：/opt/vohive/bin/vohive -c /opt/vohive/config/config.yaml
```

#### 查看日志
```bash
journalctl -u vohive -f
# 或
tail -f /opt/vohive/logs/*.log
```

#### 让 Mac 开机后自动连 VM
- UTM 设置里可勾选该 VM「开机自动启动」。
- Mac 这边可加一条 ssh config，方便 `ssh vohive` 直连。

#### 如果想把模块改回大疆身份（基本不需要）
把第 5 步的 AT 指令 VID/PID 换回原值即可：
```bash
echo 'AT+QCFG="usbcfg",0x2CA3,0x4006,1,1,1,1,1,0,0' | socat - /dev/ttyUSB2,crnl
echo 'AT+CFUN=1,1' | socat - /dev/ttyUSB2,crnl
```

### 9. 方案选型对比（为什么选 UTM）

| 方案 | 能跑对应架构 Linux | USB 直通 | 备注 |
|---|---|---|---|
| **UTM** ✅ | arm64 + amd64 均可（原生 Virtualize） | 支持 | 免费，本方案首选 |
| Parallels / VMware Fusion | 是 | 支持 | 付费（Fusion Pro 个人版免费），更省心但非必要 |
| OrbStack | 是 | ❌ 不支持 | 轻量但无 USB 直通，排除 |
| Multipass | 是 | ❌ 不支持 | 无 USB 直通，排除 |
| Docker Desktop | 是 | ❌ 困难 | 任意 USB 直通很痛，排除 |

### 10. 速查：从零到能访问 vohive 的最短路径

```bash
# Mac 上：先 uname -m 确认芯片，选方案 A(arm64) 或 B(amd64)
brew install --cask utm

# 方案 A（Apple Silicon）：
curl -L -o ~/Downloads/ubuntu-24.04-live-server-arm64.iso \
  https://cdimage.ubuntu.com/releases/24.04/release/ubuntu-24.04-live-server-arm64.iso
# 方案 B（Intel）：
curl -L -o ~/Downloads/ubuntu-24.04-live-server-amd64.iso \
  https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

# → UTM 图形界面建对应架构的 Ubuntu Server VM（Virtualize），装 OpenSSH
# → UTM USB 选项卡勾选大疆 2ca3:4006 直通
# → ssh 进 VM

# VM 里：
sudo apt-get update && sudo apt-get install -y socat usbutils
sudo modprobe option
echo 2ca3 4006 | sudo tee /sys/bus/usb-serial/drivers/option1/new_id
echo 'AT+QCFG="usbcfg",0x2C7C,0x0125,1,1,1,1,1,0,0' | socat - /dev/ttyUSB2,crnl
echo 'AT+CFUN=1,1' | socat - /dev/ttyUSB2,crnl
lsusb   # → 2c7c:0125 Quectel EC25
# → UTM 把直通重新绑到 2c7c:0125 / 物理端口
# 部署 vohive（二选一）：
#  · 方案 B(Intel/amd64，离线推荐)：下 vohive-backup.tar.gz → tar -xzf → sudo bash install.sh
#  · 方案 A(Apple Silicon/arm64，在线)：下 vohive-release-1.5.5.zip → unzip → bash install.sh（上游二进制 404 时会失败）
wget -O vohive-backup.tar.gz \
  https://raw.githubusercontent.com/wlzh/dji-4g-vohive-mac/main/vohive-backup.tar.gz
tar -xzf vohive-backup.tar.gz
cd vohive-backup
sudo bash install.sh
# → Mac 浏览器开 http://<VM-IP>:7575，admin/admin
```

---

## 让模组当 Mac 的 4G 上网卡（VoHive ↔ Mac 切换）

VoHive 之外，这颗改好身份的 EG25G 还能**直接当 Mac 的 4G 上网卡**用——插张能上网的 SIM，Mac 就能通过它走蜂窝网络。两种用途靠模组的 `usbnet` 工作模式区分，用脚本一键切换。

### 两种模式

| 模式 | `usbnet` | 模组归属 | Mac 上的表现 | 用途 |
|---|---|---|---|---|
| **VoHive 保号**（默认） | `0`（QMI） | 在 VM 里 | 无 | 切卡 / 收发短信 / eSIM 管理 |
| **Mac 上网** | `1`（ECM） | 在 Mac | 出现 ECM 网卡（en7/en8），拨号后拿 IP 上网 | Mac 走 4G |

> ⚠️ **同一时刻只能一个模式**：模组是 USB 设备，要么归 VM、要么归 Mac，不能两边同时用。

### 重要约束（先看清楚再用）

1. **不是无缝切换**：改 `usbnet` 模组必须软重启才生效，切换有 **10~30 秒中断**。
2. **两个方向不对称**：
   - **VoHive → Mac**：✅ **全自动**。VM 发一条 AT 切 ECM，模组重启时 UTM 的 USB 直通（usbredir）自动断开、模组弹回 Mac，macOS 自动认 ECM 网卡。
   - **Mac → VoHive**：⚠️ **要手动跑一次 `utmctl`**。因为 macOS 不驱动 Quectel 的串口（USB class 0xFF），Mac 这边发不了 AT 切回 QMI，必须先把模组塞回 VM（Linux 有串口）才能切。
3. **Mac 上网会走蜂窝流量 → 产生 SIM 流量费**。保号卡（尤其国际漫游）流量很贵，建议换国内流量卡再用 Mac 上网模式。
4. **这个定制固件没有「QMI + MBIM 并存」模式**（实测 `usbnet=3` 等于 ECM，不是并存），所以没法一个模式两边通用，必须切。

### 前提准备（一次性）

1. **Mac → VM 配 SSH key 免密**（脚本靠它远程发 AT / 控制 VoHive）：
   ```bash
   ssh-copy-id <VM用户>@<VM的IP>
   ssh <VM用户>@<VM的IP> 'echo OK'   # 验证: 不输密码就成功
   ```
2. **VM 里 `sudo` 免密**（脚本要 sudo 发 AT + 控制 systemd），或接受脚本在 sudo 处停下输密码：
   ```bash
   # VM 里: sudo visudo，加一行  <用户> ALL=(ALL) NOPASSWD: ALL
   ```
3. **模组里插能上网的 SIM 卡**（Mac 上网模式才需要；保号模式用保号卡即可）。
4. **拿 VM 的 IP 和 UTM 里 VM 的 UUID**：
   ```bash
   # VM 的 IP: 进 VM 跑 ip a
   # UTM VM UUID:
   plutil -p ~/Library/Containers/com.utmapp.UTM/Data/Documents/*.utm/config.plist | grep -i Identifier
   # 用第一个 UUID（VM 本体的，不是磁盘的）
   ```

### 三个脚本（在 `scripts/` 目录）

| 脚本 | 作用 | 怎么跑 |
|---|---|---|
| `eg25-status.sh` | 查模组当前在哪、什么模式、VoHive 活没活 | 随便跑 |
| `eg25-to-mac.sh` | VoHive → Mac 上网 | 全自动 |
| `eg25-to-vohive.sh` | Mac → VoHive | **必须在 Mac 终端跑**（含 utmctl） |

安装到 `/usr/local/bin/`（随处可调）：
```bash
cd dji-4g-vohive-mac/scripts
sudo install -m 755 eg25-status.sh eg25-to-mac.sh eg25-to-vohive.sh /usr/local/bin/
```

配置 VM 连接（环境变量，写进 `~/.zshrc` 或 `~/.bashrc`，不配则用脚本里的默认值）：
```bash
export VM_USER=ubuntu           # 你的 VM SSH 用户
export VM_HOST=192.168.64.2     # 你的 VM IP
export VM_NAME=Linux            # UTM 里 VM 的名字（utmctl list 看，或直接用 UUID）
```

### 切换流程

**切到 Mac 上网**（VoHive → Mac，全自动）：
```bash
eg25-to-mac.sh
# 等 30 秒，看到 "✅ 完成：Mac 上网模式" 即可
# 验证出口是不是蜂窝: curl ifconfig.me
```

**切回 VoHive 保号**（Mac → VoHive，在 Mac 终端跑）：
```bash
eg25-to-vohive.sh
# 中间会调 utmctl 连两次 USB，最后启动 VoHive
```

> ⚠️ `eg25-to-vohive.sh` 里的 `VM_NAME` 如果名字不认，把它换成 VM 的 UUID（前提准备第 4 步拿到的）。

### 故障排查

| 现象 | 排查 |
|---|---|
| `eg25-to-mac` 后 Mac 没 IP | SIM 没插好 / 模组飞行模式（进 VM 查 `AT+CFUN?` 应为 1 不是 4）/ 模组没自动拨号 |
| `eg25-to-vohive` 报 `utmctl 失败` | 没在 Mac 图形会话跑 / UTM 没开 / VM 标识不对（用 UUID） |
| VoHive 启动但报「未找到匹配 IMEI 的设备」 | 模组没真正进 VM（`eg25-status.sh` 看归属），用 UUID 重连 USB |
| 切完卡住（模组哪边都没有） | 跑 `eg25-status.sh` 看模组归属，手动 `utmctl usb connect <UUID> 2c7c:0125` 连到该在的那边 |

### 为什么不做成完全无感切换

卡在两个硬限制：
- **utmctl 远程调不动**：UTM 的命令行 `utmctl` 通过 Mach 端口连 UTM.app，只在 Mac 图形登录会话里能用，SSH（含 `launchctl asuser`）都连不上（报 `OSStatus错误-1743`）。所以含 utmctl 的步骤必须在 Mac 终端手动触发。
- **macOS 不驱动 Quectel 串口**：模组的 AT 控制口是 USB class 0xFF（vendor-specific），macOS 不给加载串口驱动，Mac 这边发不了 AT 命令，所以从 Mac 切回 QMI 必须借 VM。

要彻底免切换，只能**两个设备各管一摊**：VoHive 用一个模组保号，Mac 上网用另一个（手机热点 / 独立 4G 棒）。

---

## 致谢

- 上游项目：[iniwex5/vohive-release](https://github.com/iniwex5/vohive-release)（VoHive 平台与一键安装脚本）
- 原始教程：<https://linux.do/t/topic/2486016>（iniwex 发布的大疆 4G 模块改 ID + 部署 vohive 教程）

## License

本仓库仅含文档，按 CC-BY-4.0 分享。VoHive 二进制与脚本的上游许可请见 [iniwex5/vohive-release](https://github.com/iniwex5/vohive-release)。
