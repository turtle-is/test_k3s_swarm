# K3s vs Docker Swarm на RISC-V: CPU-бенчмарки со stress-ng

Набор скриптов и манифестов для сравнения **K3s** и **Docker Swarm** на CPU-bound нагрузке (интенсивные матричные вычисления `matrixprod` из `stress-ng`) на архитектуре **RISC-V**.

## Что тут есть

- **docker/** — `Dockerfile` с `stress-ng`, `time`, `numactl`, `lscpu` + `src/entrypoint.sh`.
- **k3s/** — `job.yaml` и скрипт автоматических прогонов `run_k3s_bench.sh`.
- **swarm/** — `stack.yaml` и скрипт автоматических прогонов `run_swarm_bench.sh`.
- **parse_results.py** — сбор метрик из папок результатов в единый `summary.csv`.
- **README.md** — это описание.

## Зависимости/предпосылки

- Узел(ы) Linux на **RISC-V**, установлен **Docker** и кластер **K3s** (или другой совместимый Kubernetes).
- Доступ к `kubectl` (настроенный kubeconfig) и/или `docker swarm` (инициализирован).
- На ноде достаточно CPU (1–4 vCPU свободных) и прав для монтирования `hostPath`/volume.

Образ по умолчанию: `nctortue/riscv-stress-ng:latest`  
(можно пересобрать: `docker build -t <user>/riscv-stress-ng:latest -f docker/Dockerfile .` и запушить в Docker Hub).

## Что делает тест

Запускает `stress-ng` со стрессором `cpu` и методом `matrixprod`:

```bash
stress-ng --cpu <N> --cpu-method matrixprod --metrics-brief --timeout <DURATION>
