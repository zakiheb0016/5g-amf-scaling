#!/bin/bash

# Exit the script on any command failure
set -e

# Function to wait for a specific pod to be in a running state
wait_for_pod_running() {
    local pod_name=$1
    while true; do
        status=$(kubectl get pods | grep "$pod_name" | awk '{print $3}')
        if [[ $status == "Running" ]]; then
            break
        else
            sleep 3
        fi
    done
}

# Read number of UEs from the file
read_ues_from_file() {
    local filename=$1
    while IFS= read -r line || [ -n "$line" ]; do
        # Extract the number of UEs from the line (even if there are extra spaces or Windows line endings)
        ue_count=$(echo "$line" | grep -o '[0-9]\+')
        echo "$ue_count"
    done <"$filename"
}

# Modify the oai-ueransim.yaml file with a new value for NUMBER_OF_UE
modify_ueransim_yaml() {
    local ue_value=$1
    sed -i "60s/.*/$(printf '          ')value: \"$ue_value\"/" oai-ueransim.yaml
}

# Modify the oai-ueransim2.yaml file with a new value for NUMBER_OF_UE
modify_ueransim2_yaml() {
    local ue_value=$1
    sed -i "60s/.*/$(printf '          ')value: \"$ue_value\"/" oai-ueransim2.yaml
}

# Function to ensure UEs have access to the core network
Ensure_Connectivity_ueransim1() {
    ueransim_pod=$(kubectl get pods --field-selector=status.phase=Running | grep 'ueransim-' | awk '{print $1}')
    # Ensure that UEs are pinging correctly
    while true; do
        # Run the ping command inside the pod
        if kubectl exec "$ueransim_pod" -- ping -I uesimtun0 8.8.8.8 -c 4 >/dev/null 2>&1; then
            break
        else
            # reRun the pod to correct the connection problem.
            kubectl delete pod $ueransim_pod
            sleep 3
            ueransim_pod=$(kubectl get pods --field-selector=status.phase=Running | grep 'ueransim-' | awk '{print $1}')
        fi
    done
}

Ensure_Connectivity_ueransim2() {
    ueransim2_pod=$(kubectl get pods --field-selector=status.phase=Running | grep 'ueransim2-' | awk '{print $1}')
    # Ensure that UEs are pinging correctly
    while true; do
        # Run the ping command inside the pod
        if kubectl exec "$ueransim2_pod" -- ping -I uesimtun0 8.8.8.8 -c 4 >/dev/null 2>&1; then
            break
        else
            kubectl delete pod $ueransim2_pod
            sleep 3
            ueransim2_pod=$(kubectl get pods --field-selector=status.phase=Running | grep 'ueransim2-' | awk '{print $1}')
        fi
    done
}
# Main function to deploy and manage UEs
deploy_ues() {
    current_ue=1           # Initial value
    modify_ueransim_yaml 1 # Set initial UE value to 1
    kubectl apply -f oai-ueransim.yaml
    wait_for_pod_running "ueransim"
    echo "Current UEs: 1"
    Ensure_Connectivity_ueransim1

    read -p "Press Enter to Read the next UE..."

    # Read UEs from the file
    for new_ue in $(read_ues_from_file "number_of_ues.txt"); do
        echo "Current UEs: $new_ue"
        if [[ $current_ue -le 10 && $new_ue -le 10 ]]; then
            modify_ueransim_yaml $new_ue
            kubectl delete -f oai-ueransim.yaml
            kubectl apply -f oai-ueransim.yaml
            wait_for_pod_running "ueransim"
            Ensure_Connectivity_ueransim1

        elif [[ $current_ue -le 10 && $new_ue -gt 10 ]]; then
            modify_ueransim_yaml $((new_ue / 2))
            modify_ueransim2_yaml $((new_ue - new_ue / 2))
            kubectl delete -f oai-ueransim.yaml
            helm uninstall upf
            helm uninstall smf
            cd oai-5g-core
            helm install amf2 oai-amf2/
            wait_for_pod_running amf2
            helm install smf oai-smf/
            wait_for_pod_running smf
            helm install upf oai-upf/
            wait_for_pod_running upf
            cd ..
            kubectl apply -f oai-ueransim.yaml
            wait_for_pod_running "ueransim"
            kubectl apply -f oai-ueransim2.yaml
            wait_for_pod_running "ueransim2"
            Ensure_Connectivity_ueransim1
            Ensure_Connectivity_ueransim2

        elif [[ $current_ue -gt 10 && $new_ue -gt 10 ]]; then
            modify_ueransim_yaml $((new_ue / 2))
            modify_ueransim2_yaml $((new_ue - new_ue / 2))
            kubectl delete -f oai-ueransim.yaml
            kubectl delete -f oai-ueransim2.yaml
            kubectl apply -f oai-ueransim.yaml
            wait_for_pod_running "ueransim"
            kubectl apply -f oai-ueransim2.yaml
            wait_for_pod_running "ueransim2"
            Ensure_Connectivity_ueransim1
            Ensure_Connectivity_ueransim2
        elif [[ $current_ue -gt 10 && $new_ue -le 10 ]]; then
            modify_ueransim_yaml $new_ue
            kubectl delete -f oai-ueransim.yaml
            kubectl delete -f oai-ueransim2.yaml
            helm uninstall amf2
            kubectl apply -f oai-ueransim.yaml
            wait_for_pod_running "ueransim"
            Ensure_Connectivity_ueransim1

        fi
        current_ue=$new_ue
        read -p "Press Enter to Read the next UE value..."
    done
}

# Deploy core functions and wait for pods to be running

cd oai-5g-core
core_functions=("nrf" "udr" "udm" "ausf" "amf" "smf" "upf")
helm install mysql mysql/
for function in "${core_functions[@]}"; do
    echo "Deploying $function..."
    helm install $function oai-$function/
    wait_for_pod_running $function
done

cd ..
# Deploy UERANSIM and handle UE scaling
deploy_ues
