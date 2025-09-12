#!/usr/bin/env bash
set -euo pipefail

# kubectl через sudo при необходимости
KUBECTL=${KUBECTL:-kubectl}
if ! $KUBECTL get nodes >/dev/null 2>&1; then
  KUBECTL="sudo kubectl"
fi

RUNS=${RUNS:-3}
VCPUS=${VCPUS:-3}
DURATION=${DURATION:-600s}           # например, 600s
K8S_NODE=${K8S_NODE:-lpi4aserver}    # имя ноды (строчными)
IMAGE=${IMAGE:-nctortue/riscv-stress-ng:latest}
RESULTS_ROOT=${RESULTS_ROOT:-/var/bench-results/k3s}

REQ_MCPU=$(( VCPUS*1000 - 100 )); [[ $REQ_MCPU -lt 100 ]] && REQ_MCPU=100
DUR_S=${DURATION%s}; TIMEOUT=$(( DUR_S + 300 ))

echo "K3s bench: RUNS=$RUNS VCPUS=$VCPUS DURATION=$DURATION NODE=$K8S_NODE"
echo "Results root: $RESULTS_ROOT"

for i in $(seq 1 "$RUNS"); do
  TS=$(date +%Y%m%d-%H%M%S)
  JOB=stress-ng-bench-$TS
  OUT_DIR="$RESULTS_ROOT/k3s-$TS-run$i"   # итоговая папка для этого прогона (буквально)
  echo "[$i/$RUNS] Job=$JOB OUT_DIR=$OUT_DIR"
  TMP=$(mktemp)

  # ВАЖНО: в block-команде ниже НЕТ ни одного $ — все значения уже подставлены здесь.
  cat >"$TMP" <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB
spec:
  completions: 1
  parallelism: 1
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: $K8S_NODE
      containers:
      - name: stress
        image: $IMAGE
        imagePullPolicy: IfNotPresent
        resources:
          requests: { cpu: "${REQ_MCPU}m", memory: "512Mi" }
          limits:   { cpu: "$VCPUS",       memory: "1Gi" }
        command: ["/bin/sh","-c"]
        args:
        - |
          mkdir -p "$OUT_DIR";
          date +"%F %T %z" | tee -a "$OUT_DIR/meta.txt";
          uname -a        | tee -a "$OUT_DIR/meta.txt";
          lscpu > "$OUT_DIR/lscpu.txt" 2>/dev/null || true;
          numactl --hardware > "$OUT_DIR/numa.txt" 2>/dev/null || true;
          /usr/bin/time -v -o "$OUT_DIR/time.txt" \
            stress-ng --cpu "$VCPUS" --cpu-method matrixprod \
                      --metrics-brief --timeout "$DURATION" \
            1> "$OUT_DIR/stress.stdout" 2> "$OUT_DIR/stress.stderr" || true;
          [ -f /sys/fs/cgroup/cpu.stat ] && cp /sys/fs/cgroup/cpu.stat "$OUT_DIR/cpu.stat" || true;
          echo "Done. Results in $OUT_DIR"
        volumeMounts:
        - name: results
          mountPath: /var/bench-results
      volumes:
      - name: results
        hostPath:
          path: /var/bench-results
          type: DirectoryOrCreate
YAML

  $KUBECTL apply -f "$TMP"
  $KUBECTL get pods -l job-name="$JOB" -o wide
  if ! $KUBECTL wait --timeout=${TIMEOUT}s --for=condition=complete job/"$JOB"; then
    echo "Job $JOB не завершился вовремя"
    POD=$($KUBECTL get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
    $KUBECTL describe job "$JOB" || true
    $KUBECTL describe pod "$POD" || true
    exit 1
  fi
  echo ">> Results: $OUT_DIR"
  $KUBECTL delete job "$JOB" --ignore-not-found >/dev/null
  rm -f "$TMP"
done
