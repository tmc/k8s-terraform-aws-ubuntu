#!/bin/bash
set -euo pipefail

KUBELET_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
KUBE_PROXY_TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
KUBE_PASSWORD=$(python -c 'import string,random; print "".join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(16))')

cat << EOF
KUBELET_TOKEN = "${KUBELET_TOKEN}"
KUBE_PROXY_TOKEN = "${KUBE_PROXY_TOKEN}"
KUBE_PASSWORD = "${KUBE_PASSWORD}"
EOF

