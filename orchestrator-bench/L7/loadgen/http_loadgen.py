import asyncio, time, json, argparse, sys
from statistics import median

def pct(arr, p):
    if not arr: return float("nan")
    k = max(0, min(len(arr)-1, int(round((p/100.0)*len(arr)+0.5))-1))
    return arr[k]

async def run(host, port, path, conc, nreq, timeout, latencies, errors):
    sem = asyncio.Semaphore(conc)
    req = f"GET {path} HTTP/1.1\r\nHost: {host}\r\nConnection: close\r\n\r\n".encode()

    async def one(_):
        async with sem:
            t0 = time.perf_counter()
            try:
                r, w = await asyncio.wait_for(asyncio.open_connection(host, port), timeout=timeout)
                w.write(req); await w.drain()
                first = await asyncio.wait_for(r.read(1), timeout=timeout)
                if not first: raise RuntimeError("empty")
                while True:
                    b = await r.read(65536)
                    if not b: break
                try: w.close(); await w.wait_closed()
                except: pass
                latencies.append((time.perf_counter()-t0)*1000.0)
            except Exception:
                errors.append(1)

    tasks = [asyncio.create_task(one(i)) for i in range(nreq)]
    await asyncio.gather(*tasks)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", type=int, default=30081)
    ap.add_argument("--path", default="/")
    ap.add_argument("--concurrency", type=int, default=32)
    ap.add_argument("--requests", type=int, default=5000)
    ap.add_argument("--timeout", type=float, default=5.0)
    ap.add_argument("--out-lat", default=None)      # CSV латенсий
    ap.add_argument("--out-summary", default=None)  # JSON summary
    args = ap.parse_args()

    lat, errs = [], []
    t0 = time.perf_counter()
    asyncio.run(run(args.host, args.port, args.path, args.concurrency, args.requests, args.timeout, lat, errs))
    dur = time.perf_counter() - t0
    lat.sort()
    out = {
        "stack": "",
        "host": args.host, "port": args.port, "path": args.path,
        "concurrency": args.concurrency, "requests": args.requests,
        "ok": len(lat), "errors": sum(errs),
        "duration_s": round(dur,3),
        "rps": round(len(lat)/dur,2) if dur>0 else 0.0,
        "p50_ms": round(pct(lat,50),2),
        "p90_ms": round(pct(lat,90),2),
        "p95_ms": round(pct(lat,95),2),
        "p99_ms": round(pct(lat,99),2)
    }

    if args.out_lat:
        with open(args.out_lat,"w") as f:
            f.write("ms\n")
            for v in lat: f.write(f"{v:.3f}\n")
    if args.out_summary:
        with open(args.out_summary,"w") as f: json.dump(out,f,ensure_ascii=False,indent=2)
    print(json.dumps(out, ensure_ascii=False))

if __name__ == "__main__":
    main()

