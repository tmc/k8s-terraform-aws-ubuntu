#!/bin/bash
# We need the salt-master to be up for the minions to work
sudo journalctl -f /usr/bin/cloud-init & 
attempt=0
while true; do
  echo -n Attempt "$(($attempt+1))" to check for salt-master
  ok=1
  output=$(pgrep salt-master) || ok=0
  if [[ ${ok} == 0 ]]; then
    if (( attempt > 60 )); then
      echo
      echo "(Failed) output was: ${output}"
      echo
      echo "salt-master failed to start"
      exit 1
    fi
  else
    echo "[salt-master running]"
    break
  fi
  echo " [salt-master not working yet]"
  attempt=$(($attempt+1))
  sleep 10
done
