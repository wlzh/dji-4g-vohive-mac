# dji-4g-vohive-mac

> 在 Mac（Apple Silicon / Intel 通用）上，用 **UTM** 跑一个 Linux 虚拟机，把**大疆 4G 模块（1 代，本质移远 Quectel EG25-G）**的 USB 身份从大疆私有 `2ca3:4006` **永久改成移远 Quectel EC25 的 `2C7C:0125`**，并在该 Linux 里一键部署 **vohive** 短信/网络/eSIM 管理平台的全套步骤。

## 这个仓库做什么

- 给 Mac 用户提供一条**从零到能访问 vohive 后台**的可执行路径，无需另一台 Linux 真机。
- 解决大疆 4G 模块默认 VID/PID 是大疆私有、通用驱动不认的问题——通过发 AT 指令 `AT+QCFG="usbcfg",...` 把模块内部 USB 身份永久改写为移远 EC25，改一次终身有效。
- 同时覆盖 **Apple Silicon（arm64）** 和 **Intel（x86_64）** 两种 Mac：两者只有 ISO 和 VM 架构不同，VM 内所有操作完全一致。
- 包含 USB 直通、改身份后重新枚举断直通的坑及处理、验证清单、维护命令、方案选型对比。

## 项目依赖

本仓库本身只是一份操作手册（README），实际起作用的是下面这个上游项目，部署步骤会调用它的一键安装脚本：

### [iniwex5/vohive-release](https://github.com/iniwex5/vohive-release)

**VoHive** 是面向高通 4G/5G 模组场景的一体化管理与代理平台，核心能力：

- 网页 / Bot 收发短信
- 多卡统一管理
- 实体 eSIM / eUICC 管理（加卡、切卡、删卡）
- 转量代理：支持 `SOCKS5/HTTP` 实例，按设备网卡强绑定出站
- TelegramBot / 飞书Bot / QQBot 远程控制
- 条件满足时启用 VoWiFi，并通过 `/vocall` 发起 VoWiFi 模拟外呼

**适用环境：** Linux（Debian/Ubuntu/树莓派/NAS）+ 移远 EC20CE / EM500Q / 高通 410 WIFI 板 / 各类高通 4G USB 模组（需 SIM 卡槽或带 SIM 卡槽的 USB 底板）。本仓库的作用正是让 Mac 用户通过 UTM Linux VM + USB 直通，把大疆 4G 模块变成 VoHive 能认的 Quectel EC25，从而跑起 VoHive。

**部署方式：** 一键脚本（本仓库采用）或 Docker Compose。
```bash
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash
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

模块身份改完且直通稳定后，在 VM 里执行：

```bash
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash
```

脚本会：
- 下载 `vohive_<版本>_linux_<arch>` 二进制到 `/opt/vohive/bin/vohive`
- 生成配置 `/opt/vohive/config/config.yaml`（默认 Web 账号密码 `admin / admin`）
- 注册 systemd 服务 `vohive.service` 并启动
- 数据/日志在 `/opt/vohive/data`、`/opt/vohive/logs`

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
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash
```
脚本会自动备份旧二进制到 `/opt/vohive/bin/vohive.bak` 再覆盖。

#### 卸载 vohive
```bash
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/uninstall.sh | bash
```

#### 不用 systemd 的环境（如容器/WSL，本方案用不到）
```bash
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash -s -- --no-systemd
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
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash
# → Mac 浏览器开 http://<VM-IP>:7575，admin/admin
```

---

## 11. 备选方案：在 arm64 常开小盒子（如全志 H618）裸机部署（不用 Mac/UTM）

如果你不想让 Mac 一直开着，更省事、更省电的做法是用一台**常开的 arm64 Linux 小盒子**（如全志 H618、4 核 + 4G 内存 + 千兆网口 + USB 口，待机 ~2W）直接跑 vohive。和上面 Mac+UTM 方案相比，这条路**没有虚拟机、没有 USB 直通**——大疆模块直接插盒子的 USB 口，所以也就**没有第 5 步那个「USB 重新枚举断直通」的坑**。

> **本节前提（不在此展开）：** 盒子已经刷好 **Armbian（Debian/Ubuntu 系，arm64）** 并能 SSH 进去；大疆 4G 模块已经插在盒子的 USB 口上。刷机、USB 供电等硬件准备不在本节范围内。
>
> 下面命令全部在 **盒子的 Linux（ssh 会话）** 里执行，和第 4~6 步几乎一致，只是少了 UTM 直通相关操作。

### 11.1 确认环境

```bash
# 确认是 arm64（应输出 aarch64）
uname -m

# 确认是 Debian/Ubuntu 系、带 systemd
cat /etc/os-release
systemctl --version | head -1
```

### 11.2 确认模块已被系统识别

```bash
# 没有 lsusb 就先装
sudo apt-get update && sudo apt-get install -y usbutils socat

# 应能看到一行含 2ca3:4006（大疆默认身份）
lsusb
```

> 看不到设备时：检查 USB 线/口，或换一个 USB 口重插；这类小盒子 USB 供电偏弱，模块掉线多半是供电问题（硬件部分本节不展开）。

### 11.3 改大疆模块设备 ID（改成移远 EC25 身份）

与第 5 步完全相同，依次执行：

```bash
# 1. 临时加载 option 驱动模块
sudo modprobe option

# 2. 把大疆当前识别码 2ca3:4006 写入 option 驱动，生成串口文件
echo 2ca3 4006 | sudo tee /sys/bus/usb-serial/drivers/option1/new_id

# 3. 通过 /dev/ttyUSB2 发 AT 指令，永久改 USB 身份为移远 2C7C:0125
echo 'AT+QCFG="usbcfg",0x2C7C,0x0125,1,1,1,1,1,0,0' | socat - /dev/ttyUSB2,crnl

# 4. 软重启模块使配置生效
echo 'AT+CFUN=1,1' | socat - /dev/ttyUSB2,crnl
```

等几秒模块重新初始化，再查：

```bash
lsusb
# 应显示：2c7c:0125 Quectel Wireless Solutions Co., Ltd. EC25 LTE modem
```

> **裸机和 Mac 方案的唯一区别就在这一步：** 没有 UTM 直通，`AT+CFUN=1,1` 让模块重新枚举（VID/PID 从 `2ca3:4006` 变 `2c7c:0125`）后，**设备依然留在本机**，不会像直通那样断开。如果重新枚举后 `/dev/ttyUSBx` 串口号变了，重跑一次 `lsusb` 确认即可。改身份是一次性的，改完终身有效。
>
> 万一 `/dev/ttyUSB2` 不存在，用 `ls /dev/ttyUSB*` 看实际串口号（通常 ttyUSB0~3，AT 口一般是第 3 个，即 ttyUSB2），把上面命令里的设备名换成实际的。

### 11.4 一键部署 vohive

模块身份改完后，直接在盒子里跑官方脚本（会自动识别 arm64 并下载 `vohive_<版本>_linux_arm64`）：

```bash
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash
```

脚本会：

- 下载二进制到 `/opt/vohive/bin/vohive`
- 生成配置 `/opt/vohive/config/config.yaml`（默认 Web 账号密码 `admin / admin`）
- 注册并启动 systemd 服务 `vohive.service`（**开机自动启动，盒子常开即长期运行**）
- 数据/日志在 `/opt/vohive/data`、`/opt/vohive/logs`

### 11.5 访问后台与验证

先在盒子里看它的局域网 IP：

```bash
ip a    # 找 eth0 上的 192.168.x.x
```

从同一局域网的电脑/手机浏览器打开：

```
http://<盒子的IP>:7575
```

默认 `admin / admin`，**登录后立即改密码**。

验证清单：

- [ ] `uname -m` 是 `aarch64`
- [ ] `lsusb` 能看到 `2c7c:0125 Quectel ... EC25 LTE modem`
- [ ] `systemctl status vohive` 显示 active (running)
- [ ] 浏览器访问 `http://<盒子IP>:7575` 出登录页，`admin/admin` 能登录并改密
- [ ] vohive 后台能识别到 4G 模块、看到信号/短信等功能

### 11.6 维护

```bash
# 看服务状态 / 日志
systemctl status vohive
journalctl -u vohive -f

# 更新（自动备份旧二进制为 vohive.bak 再覆盖）
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash

# 卸载
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/uninstall.sh | bash
```

> 因为是 systemd 服务且盒子常开，**断电重启后 vohive 会自动拉起**，不需要像 Mac 方案那样依赖宿主机开机——这正是用常开 Linux 小盒子替代 Mac+UTM 的核心好处。

---

## 致谢

- 上游项目：[iniwex5/vohive-release](https://github.com/iniwex5/vohive-release)（VoHive 平台与一键安装脚本）
- 原始教程：<https://linux.do/t/topic/2486016>（iniwex 发布的大疆 4G 模块改 ID + 部署 vohive 教程）

## License

本仓库仅含文档，按 CC-BY-4.0 分享。VoHive 二进制与脚本的上游许可请见 [iniwex5/vohive-release](https://github.com/iniwex5/vohive-release)。
