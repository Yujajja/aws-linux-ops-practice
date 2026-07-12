#!/bin/bash

RESULT_FILE="/tmp/server_check_result.txt"

{
echo "===================================="
echo " Linux Server Check Report"
echo "===================================="
echo "Check Time: $(date)"
echo "Hostname: $(hostname)"
echo ""

echo "[1] Uptime / Load Average"
uptime
echo ""

echo "[2] Memory Usage"
free -h
echo ""

echo "[3] Disk Usage"
df -h
echo ""

echo "[4] Listening Ports"
ss -tulnp | grep -E ':80|:22' || echo "No 80/22 port found"
echo ""

echo "[5] Nginx Service Status"
systemctl is-active nginx
systemctl is-enabled nginx
echo ""

echo "[6] Recent Nginx Logs"
journalctl -u nginx --no-pager | tail -n 20
echo ""

echo "===================================="
echo " Check Complete"
echo "===================================="
} | tee "$RESULT_FILE"
