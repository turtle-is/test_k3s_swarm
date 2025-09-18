#!/usr/bin/env python3
import asyncio, time, random, json, argparse

def pct(arr, p):
    if not arr: return float("nan")
    k = max(0, min(len(arr)-1, int(round((p/100.0)*len(arr)+0.5))-1))
    return arr[k]

async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", type=int, default=30081)
    ap.add_argument("--duration", type=int, default=1800)   # 30 min по умолчанию
    ap.add_argument("--concurrency", type=int, default=32)
    ap.add_argument("--timeout", type=float, default=5.0)
    ap.add_argument("--out-lat", default=None)
    ap.add_argument("--out-summary", default=None)
    ap.add_argument("--mix", default="/:0.2,/small:0.4,/medium:0.3,/large:0.1")
    args = ap.parse_args()

    paths = []
    for token in args.mix.split(","):
        p, w = token.split(":"); w = float(w)
        paths += [p] * max(1, int(w*100))

    sem = asyncio.Semaphore(args.concurrency)
    req_cache = {}
    lat = []; errs = 0
    start = time.time()

    async def worker():
        nonlocal errs
        while time.time() - start < args.duration:
            p = random.choice(paths)
            if p not in req_cache:
                req_cache[p] = f"GET {p} HTTP/1.1\r\nHost: {args.host}\r\nConnection: close\r\n\r\n".encode()
            async with sem:
                t0 = time.perf_counter()
                try:
                    r, w = await asyncio.wait_for(asyncio.open_connection(args.host, args.port), timeout=args.timeout)
                    w.write(req_cache[p]); await w.drain()
                    first = await asyncio.wait_for(r.read(1), timeout=args.timeout)
                    if not first: raise RuntimeError("empty")
                    while await r.read(65536): pass
                    try: w.close(); await w.wait_closed()
                    except: pass
                    lat.append((time.perf_counter()-t0)*1000.0)
                except Exception:
                    errs += 1

    tasks = [asyncio.create_task(worker()) for _ in range(args.concurrency)]
    await asyncio.gather(*tasks)
    lat.sort()
    dur = time.time() - start
    out = {
        "duration_s": round(dur,1), "ok": len(lat), "errors": errs,
        "rps": round(len(lat)/dur,2) if dur>0 else 0.0,
        "p50_ms": round(pct(lat,50),2), "p90_ms": round(pct(lat,90),2),
        "p95_ms": round(pct(lat,95),2), "p99_ms": round(pct(lat,99),2)
    }
    if args.out_lat:
        with open(args.out_lat,"w") as f:
            f.write("ms\n"); [f.write(f"{v:.3f}\n") for v in lat]
    if args.out_summary:
        with open(args.out_summary,"w") as f: json.dump(out,f,ensure_ascii=False,indent=2)
    print(json.dumps(out, ensure_ascii=False))

if __name__ == "__main__":
    asyncio.run(main())

