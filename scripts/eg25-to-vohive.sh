#!/bin/bash
# eg25-to-vohive.sh — 切到「VoHive 保号模式」：Mac(ECM) → VoHive(QMI)
#
# 原理：
#   1. utmctl 把模组从 Mac 连回 VM（此时是 ECM 模式进来）
#   2. VM 发 AT+QCFG="usbnet",0 切回 QMI
#   3. 模组软重启 → USB 重新枚举 → 弹回 Mac（已是 QMI 模式）
#   4. utmctl 再连一次 VM（QMI 模式进来，/dev/cdc-wdm0 出现）
#   5. 启动 VoHive
#
# 方向特点：⚠️ 必须在 Mac 图形会话里跑（含 utmctl，SSH 远程调不动，见 README 说明）
#
# 前提：
#   - 模组当前在 Mac（处于 Mac 上网/ECM 模式）
#   - Mac → VM 已配 SSH key 免密
#   - 本脚本在 Mac 的「终端」App 里跑（不能 SSH 进 Mac 跑）
#
# 为什么这个方向不能全自动：macOS 不驱动 Quectel 的串口（USB class 0xFF），
# Mac 这边发不了 AT 切回 QMI，必须先把模组塞回 VM（Linux 有串口）才能发 AT。

set -u

: "${VM_USER:=ubuntu}"
: "${VM_HOST:=192.168.64.2}"
: "${VM_NAME:=Linux}"            # utmctl list 看真实名字
VIDPID="2c7c:0125"
UTM=/Applications/UTM.app/Contents/MacOS/utmctl
O=(-o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10)
VM="${VM_USER}@${VM_HOST}"

echo "[1/6] 模组连到 VM（ECM 模式进来）..."
$UTM usb connect "$VM_NAME" "$VIDPID" \
  || { echo "  ✗ utmctl 失败：确认 ①在 Mac 图形会话跑（不是 SSH 进来）②UTM 开着 ③VM 名对（utmctl list 看）"; exit 1; }

echo "[2/6] 等 VM 识别模组（8s）..."
sleep 8

echo "[3/6] VM 发 AT+QCFG=usbnet,0（切 QMI；ECM 模式下 ttyUSB3 是 AT 口）..."
ssh "${O[@]}" "$VM" "sudo bash -c 'stty -F /dev/ttyUSB3 115200 raw -echo 2>/dev/null; printf \"AT+QCFG=\\\"usbnet\\\",0\r\" > /dev/ttyUSB3; sleep 2'" \
  && echo "    ✓ AT 已发" || echo "    （ttyUSB3 不通就试 ttyUSB2；或模组已是 QMI，跳过无妨）"

echo "[4/6] 等模组软重启弹回 Mac（12s），再把模组连回 VM（QMI 模式）..."
sleep 12
$UTM usb connect "$VM_NAME" "$VIDPID" || echo "    （第二次连接失败，可能模组还没回 Mac，稍等重跑本脚本）"

echo "[5/6] 等 QMI 接口 cdc-wdm0 出现（5s）..."
sleep 5

echo "[6/6] 启动 VoHive..."
ssh "${O[@]}" "$VM" "sudo systemctl start vohive" && echo "    ✓ 已启动"
sleep 4

echo ""
echo "✅ 完成：VoHive 保号模式"
echo "   VoHive: $(ssh "${O[@]}" "$VM" 'systemctl is-active vohive 2>/dev/null')"
echo "   QMI cdc-wdm0: $(ssh "${O[@]}" "$VM" 'ls /dev/cdc-wdm0 2>/dev/null && echo 存在 || echo 无）' 2>/dev/null)"
echo "   后台地址: http://${VM_HOST}:7575"
