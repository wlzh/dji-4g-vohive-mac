#!/bin/bash
# eg25-status.sh — 查询 EG25G 模组当前状态（Mac 上网 ↔ VoHive 两种模式下分别在哪、通不通）
#
# 依赖：Mac → VM 已配好 SSH key 免密（见 README「前提准备」）
# 用法：直接运行，或 VM_USER/VM_HOST/VM_NAME 环境变量覆盖默认值
#
# 隐私：本脚本不含任何密码/IP，全部走环境变量 + SSH key。

set -u

: "${VM_USER:=ubuntu}"            # VM 的 SSH 用户名（你在第 3 步装 Ubuntu 时设的）
: "${VM_HOST:=192.168.64.2}"      # VM 的 IP（VM 里 `ip a` 看，UTM NAT 默认 192.168.64.x）
: "${VM_NAME:=Linux}"             # UTM 里虚拟机的名字（`utmctl list` 看）

VIDPID="2c7c:0125"                # 改完身份后的 Quectel EC25 USB ID（通用）
O=(-o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5)

echo "=== Mac 侧 ==="
mac_cnt=$(system_profiler SPUSBDataType 2>/dev/null | grep -ciE '2c7c:0125|quectel.*EC25')
echo "  USB 模组在 Mac 主机：${mac_cnt} 处（>0 = 模组现在归 Mac）"
ecm_nic=""
for n in en5 en6 en7 en8 en9 en10; do
  ip=$(ipconfig getifaddr "$n" 2>/dev/null)
  if [ -n "$ip" ]; then
    # 只认模组出来的 ECM 网卡（排除 Wi-Fi en0 / Thunderbolt en1-4）
    driver=$(ioreg -p IOService -l -w 0 2>/dev/null | grep -A30 "\"BSD Name\" = \"$n\"" | grep -m1 -oE 'AppleUSB.*?(NCM|ECM|MBIM)' || true)
    case "$driver" in AppleUSBNCM*|AppleUSBECM*) ecm_nic="$n ($ip, $driver)";; esac
  fi
done
echo "  ECM 上网口：${ecm_nic:-无（模组不在 Mac 或未拨号）}"

echo "=== VM 侧（${VM_USER}@${VM_HOST}）==="
if ssh "${O[@]}" "${VM_USER}@${VM_HOST}" true 2>/dev/null; then
  vm_cnt=$(ssh "${O[@]}" "${VM_USER}@${VM_HOST}" 'lsusb 2>/dev/null | grep -ciE 2c7c:0125' 2>/dev/null)
  echo "  模组在 VM：${vm_cnt:-0} 处（>0 = 模组现在归 VM）"
  echo "  QMI 控制设备 cdc-wdm0：$(ssh "${O[@]}" "${VM_USER}@${VM_HOST}" 'ls /dev/cdc-wdm0 2>/dev/null && echo "存在（VoHive 可用）" || echo "无（VoHive 用不了）"' 2>/dev/null)"
  echo "  VoHive 服务：$(ssh "${O[@]}" "${VM_USER}@${VM_HOST}" 'systemctl is-active vohive 2>/dev/null' 2>/dev/null)"
else
  echo "  ⚠️ SSH 连不上 VM —— 检查 VM_HOST/VM_USER、VM 是否开机、SSH key 是否配好"
fi

echo ""
echo "=== 当前模式判断 ==="
if [ "${mac_cnt:-0}" -gt 0 ] && [ -n "$ecm_nic" ]; then
  echo "  → Mac 上网模式（ECM）"
elif [ "${vm_cnt:-0}" -gt 0 ] 2>/dev/null; then
  echo "  → VoHive 保号模式（QMI）"
else
  echo "  → 模组在 Mac 但没 ECM 上网口（可能 QMI 模式卡在中间，见 README 故障排查）"
fi
