#!/bin/bash
# eg25-to-mac.sh — 切到「Mac 上网模式」：VoHive(QMI) → Mac(ECM)
#
# 原理：
#   1. VM 里停掉 VoHive，释放模组
#   2. VM 里发 AT+QCFG="usbnet",1 把模组切到 ECM 模式
#   3. 模组改 usbnet 会软重启 → USB 重新枚举 → UTM 的 usbredir 直通自动断开
#      → 模组「弹回」Mac 主机（这一步无需手动点 UTM）
#   4. macOS 原生认 CDC-ECM 网卡，模组拨号后给 Mac 分 IP，即可上网
#
# 方向特点：✅ 全自动（只发一条 AT，模组自动回 Mac，不用动 UTM）
#
# 前提：
#   - 模组当前在 VM、VoHive 在跑（即处于 VoHive 保号模式）
#   - Mac → VM 已配 SSH key 免密
#   - VM 里 m/ubuntu 用户能 sudo（建议配 NOPASSWD，否则脚本会在 sudo 处停下要密码）
#   - 模组里插了能上网的 SIM 卡并已配好 APN（否则 ECM 口拿不到 IP）
#
# ⚠️ 注意：切过去真的会走蜂窝流量 → 产生 SIM 卡流量费用。保号卡（尤其国际漫游）
#    流量很贵，建议换国内流量卡再用这模式。

set -u

: "${VM_USER:=ubuntu}"
: "${VM_HOST:=192.168.64.2}"
O=(-o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10)
VM="${VM_USER}@${VM_HOST}"

echo "[1/4] 停 VoHive..."
ssh "${O[@]}" "$VM" "sudo systemctl stop vohive" && echo "    ✓ 已停" || echo "    （停失败或本就没跑，继续）"

echo "[2/4] VM 发 AT+QCFG=usbnet,1（切 ECM；QMI 模式下 ttyUSB2 是 AT 口）..."
ssh "${O[@]}" "$VM" "sudo bash -c 'stty -F /dev/ttyUSB2 115200 raw -echo 2>/dev/null; printf \"AT+QCFG=\\\"usbnet\\\",1\r\" > /dev/ttyUSB2; sleep 2'" \
  && echo "    ✓ AT 已发" || { echo "    ✗ 发 AT 失败（模组不在 VM？先 eg25-status 看状态）"; exit 1; }

echo "[3/4] 等模组软重启 + 自动弹回 Mac（15s）..."
sleep 15

echo "[4/4] 等 macOS 识别 ECM 网卡并拿到 IP..."
ip=""
nic=""
for i in $(seq 1 12); do
  for n in en5 en6 en7 en8 en9 en10; do
    ip=$(ipconfig getifaddr "$n" 2>/dev/null)
    if [ -n "$ip" ]; then
      drv=$(ioreg -p IOService -l -w 0 2>/dev/null | grep -A30 "\"BSD Name\" = \"$n\"" | grep -m1 -oE 'AppleUSB(NCM|ECM)' || true)
      [ -n "$drv" ] && { nic="$n"; break; }
    fi
  done
  [ -n "$nic" ] && break
  sleep 3
done

if [ -n "$ip" ]; then
  echo ""
  echo "✅ 完成：Mac 上网模式"
  echo "   网卡 $nic，IP $ip"
  echo "   提示：用完想切回保号，跑 eg25-to-vohive.sh"
else
  echo ""
  echo "❌ ECM 网卡没拿到 IP。检查："
  echo "   - SIM 卡是否插好、是否能上网（AT+CSQ 查信号、AT+CGACT? 查数据连接）"
  echo "   - 模组是否处于飞行模式（AT+CFUN? 应为 1，不是 4）"
  echo "   - 现在模组已在 Mac，可跑 eg25-status.sh 确认归属"
fi
