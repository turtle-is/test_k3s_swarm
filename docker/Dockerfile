FROM riscv64/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    stress-ng time numactl hwloc procps \
    linux-tools-common linux-tools-generic \
 && rm -rf /var/lib/apt/lists/*

# создать symlink /usr/bin/perf, если perf установлен в /usr/lib/linux-tools-*/
RUN set -eux; \
    perf_path="$(ls -1 /usr/lib/linux-tools-*/perf 2>/dev/null | head -n1 || true)"; \
    if [ -n "$perf_path" ]; then ln -s "$perf_path" /usr/bin/perf; fi

ENV STRESS_DURATION=60s \
    STRESS_CPU=4 \
    STRESS_CPU_METHOD=matrixprod \
    PERF_EVENTS="task-clock,cycles,instructions,branches,branch-misses,cache-references,cache-misses,context-switches,cpu-migrations,page-faults"

WORKDIR /app
COPY src/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

VOLUME ["/results"]
ENTRYPOINT ["/app/entrypoint.sh"]
