#!/usr/bin/env python3
import json, argparse, csv, math, statistics as st
from datetime import datetime, timezone

def pct(arr, p):
    if not arr: return float("nan")
    k = max(0, min(len(arr)-1, int(round((p/100.0)*len(arr)+0.5))-1))
    return arr[k]

def load_lat_csv(path):
    lat = []
    with open(path) as f:
        r = csv.reader(f)
        header = next(r, None)
        col = 0 if not header or header[0] == "ms" else header.index("ms")
        for row in r:
            try: lat.append(float(row[col]))
            except: pass
    lat.sort()
    return lat

def load_node_csv(path):
    rows = []
    with open(path) as f:
        r = csv.DictReader(f)
        for row in r:
            rows.append({k: float(v) if k!="ts" else int(v) for k,v in row.items()})
    return rows

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lat", required=True)      # CSV латенсий
    ap.add_argument("--summary", required=False) # JSON summary (для вывода)
    ap.add_argument("--node", required=False)    # метрики ноды CSV
    args = ap.parse_args()

    lat = load_lat_csv(args.lat)
    out = {
        "count": len(lat),
        "p50_ms": round(pct(lat,50),2),
        "p90_ms": round(pct(lat,90),2),
        "p95_ms": round(pct(lat,95),2),
        "p99_ms": round(pct(lat,99),2),
        "avg_ms": round(st.mean(lat),2) if lat else float("nan"),
    }

    if args.node:
        rows = load_node_csv(args.node)
        peaks = {
            "max_cpu_usage_pct": round(max((r["cpu_usage_pct"] for r in rows), default=0.0),2),
            "max_mem_used_mb": round(max((r["mem_used_mb"] for r in rows), default=0.0),1),
            "max_net_rx_kbps": round(max((r["net_rx_kbps"] for r in rows), default=0.0),1),
            "max_net_tx_kbps": round(max((r["net_tx_kbps"] for r in rows), default=0.0),1),
            "max_disk_r_kbps": round(max((r["disk_r_kbps"] for r in rows), default=0.0),1),
            "max_disk_w_kbps": round(max((r["disk_w_kbps"] for r in rows), default=0.0),1),
        }
        out["peaks"] = peaks

    print(json.dumps(out, ensure_ascii=False, indent=2))
    if args.summary:
        with open(args.summary,"w") as f: json.dump(out, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    main()

