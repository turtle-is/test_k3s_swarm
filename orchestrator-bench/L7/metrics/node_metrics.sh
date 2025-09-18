#!/usr/bin/env bash
set -euo pipefail
OUT=${1:-node_metrics.csv}
echo "ts,cpu_usage_pct,mem_used_mb,mem_total_mb,net_rx_kbps,net_tx_kbps,disk_r_kbps,disk_w_kbps" > "$OUT"

read cpu_prev_total cpu_prev_idle < <(awk '/^cpu /{t=$2+$3+$4+$5+$6+$7+$8; print t,$5}' /proc/stat)
net_prev_rx=$(awk '$1!~/:lo:/{rx+=$2}END{print rx}' /proc/net/dev)
net_prev_tx=$(awk '$1!~/:lo:/{tx+=$10}END{print tx}' /proc/net/dev)
disk_prev_r=$(awk 'NR>2{r+=$6}END{print r}' /proc/diskstats)
disk_prev_w=$(awk 'NR>2{w+=$10}END{print w}' /proc/diskstats)
SECT=512

while true; do
  sleep 1
  TS=$(date +%s)
  read cpu_total cpu_idle < <(awk '/^cpu /{t=$2+$3+$4+$5+$6+$7+$8; print t,$5}' /proc/stat)
  dt=$((cpu_total - cpu_prev_total)); di=$((cpu_idle - cpu_prev_idle))
  cpu_prev_total=$cpu_total; cpu_prev_idle=$cpu_idle
  cpu_pct=$(awk -v dt="$dt" -v di="$di" 'BEGIN{if (dt>0) print (dt-di)*100/dt; else print 0}')

  read mt ma < <(awk '/MemTotal:/{mt=$2}/MemAvailable:/{ma=$2}END{print mt,ma}' /proc/meminfo)
  mem_used_mb=$(awk -v mt="$mt" -v ma="$ma" 'BEGIN{print (mt-ma)/1024}')
  mem_total_mb=$(awk -v mt="$mt" 'BEGIN{print mt/1024}')

  net_rx=$(awk '$1!~/:lo:/{rx+=$2}END{print rx}' /proc/net/dev)
  net_tx=$(awk '$1!~/:lo:/{tx+=$10}END{print tx}' /proc/net/dev)
  rx_kbps=$(awk -v c="$net_rx" -v p="$net_prev_rx" 'BEGIN{print (c-p)*8/1024}')
  tx_kbps=$(awk -v c="$net_tx" -v p="$net_prev_tx" 'BEGIN{print (c-p)*8/1024}')
  net_prev_rx=$net_rx; net_prev_tx=$net_tx

  dr=$(awk 'NR>2{r+=$6}END{print r}' /proc/diskstats)
  dw=$(awk 'NR>2{w+=$10}END{print w}' /proc/diskstats)
  r_kbps=$(awk -v c="$dr" -v p="$disk_prev_r" -v s="$SECT" 'BEGIN{print (c-p)*s/1024}')
  w_kbps=$(awk -v c="$dw" -v p="$disk_prev_w" -v s="$SECT" 'BEGIN{print (c-p)*s/1024}')
  disk_prev_r=$dr; disk_prev_w=$dw

  printf "%s,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n" "$TS" "$cpu_pct" "$mem_used_mb" "$mem_total_mb" "$rx_kbps" "$tx_kbps" "$r_kbps" "$w_kbps" >> "$OUT"
done

