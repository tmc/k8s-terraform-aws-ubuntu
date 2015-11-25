#!/bin/bash
# We need the kubernetes apiserver to be up to finish provisioning
sudo journalctl -u docker &
attempt=0
while true; do
  echo -n Attempt "$(($attempt+1))" to check for kube-apiserver
  ok=1
  output=$(pgrep kube-apiserver) || ok=0
  if [[ ${ok} == 0 ]]; then
    if (( attempt > 30 )); then
      echo
      echo "(Failed) output was: ${output}"
      echo
      echo "kube-apiserver failed to start"
      exit 1
    fi
  else
    echo "[kube-apiserver running]"
    break
  fi
  echo " [kube-apiserver not working yet]"
  attempt=$(($attempt+1))
  sleep 10
done
