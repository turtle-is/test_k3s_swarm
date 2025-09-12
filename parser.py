# parse_results.py
import re, csv
from pathlib import Path

roots = [Path("/var/bench-results/k3s"), Path("/var/bench-results/swarm")]
rows = []
for root in roots:
    if not root.exists(): continue
    for run in sorted(root.glob("*-run*")):
        if not run.is_dir(): continue
        rec = {"where": root.name, "dir": str(run)}

        # meta: выцепим N vCPU
        meta = (run / "meta.txt").read_text(errors="ignore") if (run/"meta.txt").exists() else ""
        m = re.search(r"cpu=(\d+)", meta)
        if m: rec["vcpu"] = int(m.group(1))

        # stress-ng: bogo-ops/s (real time)
        st = (run / "stress.stderr").read_text(errors="ignore") if (run/"stress.stderr").exists() else ""
        m = re.search(r"\bcpu\s+\d+\s+\d+\s+\d+\.\d+\s+\d+\.\d+\s+\d+\.\d+\s+([0-9.]+)\s+[0-9.]+\s*$", st, re.M)
        if m: rec["bogo_ops_s_real"] = float(m.group(1))

        # time.txt: user/sys/elapsed
        tt = (run / "time.txt").read_text(errors="ignore") if (run/"time.txt").exists() else ""
        def f(pattern):
            m = re.search(pattern, tt)
            return float(m.group(1)) if m else None
        rec["user_s"] = f(r"User time \(seconds\):\s*([0-9.]+)")
        rec["sys_s"]  = f(r"System time \(seconds\):\s*([0-9.]+)")
        m = re.search(r"Elapsed.*:\s*([0-9:]+\.?[0-9]*)", tt)
        if m:
            parts = m.group(1).split(":")
            rec["elapsed_s"] = float(parts[-1]) + (60*int(parts[-2]) if len(parts)>=2 else 0) + (3600*int(parts[-3]) if len(parts)>=3 else 0)

        # cpu.stat
        ct = (run / "cpu.stat").read_text(errors="ignore") if (run/"cpu.stat").exists() else ""
        for line in ct.splitlines():
            if " " in line:
                k,v = line.split()
                rec[f"cg_{k}"] = int(v)

        # оценка загрузки CPU
        if rec.get("user_s") and rec.get("elapsed_s") and rec.get("vcpu"):
            rec["cpu_load_pct"] = 100.0*rec["user_s"]/(rec["elapsed_s"]*rec["vcpu"])

        rows.append(rec)

with open("summary.csv","w",newline="") as f:
    keys = sorted({k for r in rows for k in r.keys()})
    w = csv.DictWriter(f, fieldnames=keys)
    w.writeheader(); w.writerows(rows)
print(f"OK -> summary.csv ({len(rows)} rows)")
