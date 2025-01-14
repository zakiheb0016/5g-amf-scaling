# Context

Dynamic scaling is an essential feature that every system must have, to scale up when the system encounters high traffic to accommodate the needs and scale down when the traffic is low to save resources. In 5G networks, the core network is constituted of functions. These functions must be able to handle the UEs (User Equipments) and their traffic. Thus, they need to scale up and down depending on the number of equipments connected to the core network and the traffic they generate.

# Project Overview

Our project focuses on AMF dynamic scaling depending on the number of UEs connected to the network. The core network starts with a single AMF. A second AMF is deployed (scaling up) if the number of UEs exceeds a certain threshold and gets undeployed (scaling down) if the number of UEs falls short of the threshold.

# Implementation

To achieve scalability, we implemented a script called `driver.sh` written in Bash. The script starts by initializing all the core network functions (with only one AMF) and a single UERANSIM (Radio part simulator, which contains both the gNB and the UEs connected to it) with one UE. The driver then reads the value of the number of UEs from the file `number_of_ues.txt`. The scaling feature depends on the current number of UEs and the new number read from the file, handling the situation as follows:

- **If (current_number <= 10 and new_number <= 10):**  
    - Change the number of UEs in the UERANSIM config file (`ueransim.yaml`).  
    - Redeploy UERANSIM with the new number of UEs.

- **If (current_number <= 10 and new_number > 10) (scaling-up):**  
    - Assign half of the UEs to the first UERANSIM and the other half to UERANSIM2.  
    - Undeploy UPF and SMF (because AMFs depend on them, so AMFs must be run before).  
    - Deploy AMF2, SMF, and UPF.  
    - Deploy UERANSIM and UERANSIM2 with new values.

- **If (current_number > 10 and new_number > 10):**  
    - Assign half of the UEs to the first UERANSIM and the other half to UERANSIM2.  
    - Deploy UERANSIM and UERANSIM2 with new values.

- **If (current_number > 10 and new_number <= 10):**  
    - Assign all the UEs to the first UERANSIM.  
    - Undeploy AMF2.  
    - Deploy the first UERANSIM with new values.

When the script adapts the core network to handle the current load, it waits for the user to press "Enter" to move to the next value in the text file.

To stop all the network functions and the radio part in one shot, we implemented a cleaner script `clean.sh` that stops both the core and radio parts.
