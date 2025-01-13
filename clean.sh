#!/bin/bash

# Exit the script on any command failure
set -e

kubectl delete -f oai-ueransim.yaml || true
kubectl delete -f oai-ueransim2.yaml || true
helm uninstall amf || true
helm uninstall amf2 || true

core_functions=("upf" "smf" "ausf" "udm" "udr" "nrf" "mysql")
for function in "${core_functions[@]}"; do
  echo "Uninstalling $function..."
  helm uninstall $function || true
done
