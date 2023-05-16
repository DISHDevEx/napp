# Welcome to Respons's Traffic Simulator

This tool kit is meant to enable large scale UE simulation to put load on the open5gs and UERANSIM infrastructure.   

# Prerequisites:
1. Set up your machine with the following CLI tools:

    - AWS CLI

    - Kubectl

    - Helm

2. Set up your local AWS CLI Environment Variables.

3. Update local kubectl config file.

```console
aws eks --region us-east-1 update-kubeconfig --name response_expirimentation_cluster
```

4. Add openverso to your helm repo.
```console
helm repo add openverso https://gradiant.github.io/openverso-charts/
```

# How to create loads

### Update the test_case_values.json
Add more load cases, or update previous load case parameters.

### Using the script generation files:

1. Create scripts that populate list of UEs in the Open5Gs MongoBD.
```console
python ue_populate_creation.py
```

2. Create scripts that emulate ping requests by those UEs.
```console
python ping_test_creation.py
```

3. Create scripts that emulate CURL requests by those UEs.
```console
python curl_test_creation.py
```

# How to generate load on open5gs and UERANSIM with a large ue population

### Setup Multi-UE Environment

1. Install open5gs in the namespace openverso. (2.5 mins)
```console
helm -n openverso install open5gs openverso/open5gs --version 2.0.9 --values https://raw.githubusercontent.com/DISHDevEx/napp/main/napp/open5gs_values/5gSA_no_ues_values.yaml
```

2. Populate (5 mins)

    2a. Open the terminal for the populate pod.
    ```console
    kubectl -n openverso exec -ti deployment/open5gs-populate -- /bin/bash
    ```
    2b. Run population script.

    Paste contents of `openverso-charts/respons_ue_test_kit/simulation_scripts/ue_populate.sh` inside the terminal for the populate pod.

    2c. View the populated list.
    ```console
    open5gs-dbctl showpretty
    ```

    When complete, `exit` the populate pod's terminal.

3. Install gNB in the namespace openverso. (1 minute)
```console
helm -n openverso install ueransim-gnb openverso/ueransim-gnb --version 0.2.5 --values https://raw.githubusercontent.com/DISHDevEx/napp/main/napp/open5gs_values/gnb_no_ues_values.yaml
```
4. Install the first batch of 450 ues.	(1 minute)
```console
helm install -n openverso ueransim-ues-first-batch openverso/ueransim-ues --values https://raw.githubusercontent.com/DISHDevEx/napp/main/napp/open5gs_values/0_450_ue_values.yaml
```
(Note: The text returned with this command does not give the correct command to ther the UEs terminal; see below.)

Optional: (The following can cause bugs in the app. Wait for the previous batch to fully connect all of the UEs before starting the next batch.)

5. Install second batch of 450 UEs. (3 mins)
```console
helm install -n openverso ueransim-ues-second-batch openverso/ueransim-ues --values https://raw.githubusercontent.com/DISHDevEx/napp/main/napp/open5gs_values/450_900_ue_values.yaml
```

6. install third batch of 450 ues (15 mins)
```console
helm install -n openverso ueransim-ues-third-batch openverso/ueransim-ues --values https://raw.githubusercontent.com/DISHDevEx/napp/main/napp/open5gs_values/900_1350_ue_values.yaml
```

### Enter the Terminal of a UE pod

```console
kubectl -n openverso exec -ti deployment/ueransim-ues-first-batch -- /bin/bash
```

Similarly for the pods for the other UEs.
```console
kubectl -n openverso exec -ti deployment/ueransim-ues-second-batch -- /bin/bash

kubectl -n openverso exec -ti deployment/ueransim-ues-third-batch -- /bin/bash
```

### Ensure all tunnels are connected
From within the pod for the UEs, use the Openg5Gs provided a command to see all the international mobile subscriber identities (IMSI) in the pod.
```console
nr-cli --dump
```
It may be that not all of these UEs was connected. View the networking information for the UEs.
```console
ip addr
```
- Each connected UE has a container networking interface (CNI) `uesimtun{number}` as a network infterface card (NIC). Each NIC has IPv4 and IPv6 addresses.

### Enter the terminal of a UE

If the IMSI 999700000000001 is on eof the registered UEs, then enter the CLI for that UE.
```bash
nr-cli imsi-999700000000001
```
List the available commands with `commands`.

View the PDU session set up for this UE with `ps-list`. Note that
- the session type connects this UE to the data network (access point name, APN) called `internet`.
- The single network slice selection assistance information (S-NSSAI) says that
    -   the slice is of slice service type 1, meaning enhanced mobile broadband, eMBB.
    -   the slice is differentiated by other slices of that type by the slice differentiator (SD) number 0x111111.
- the aggregate maximum bit rate is set to 1Gbps for both uplink and downlink; this is the anticipated maximum sum of data flow rates for all quality of service flows (QoS flows) for the UE that are not of the guraranteed flow rate (GFR) type.

press `control+c` to exit the terminal of the UE.

### Run curl/ping tests
To run curl or ping tests via UEs, have the terminals for the UE pods open from the previous step.

paste the contents of either of the following files (inside the terminal for an UE pod):

```console
respons_ue_test_kit/simulation_scripts/curl.sh

respons_ue_test_kit/simulation_scripts/ping.sh
```

### Traffic Sim Automator & Process killer Setup
Traffic sim is automated using kubernetes cronjob, below link provides steps on how to setup a cronjob.
https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/

Traffic sim cronjob needs access to all the pods in the cluster. Service account, clusterrole and clusterrolebinding objects need to be created to get the required access for the cronjob.

Run the top 3 commands only once when you are setting up the cronjob's in new cluster.
```console
kubectl apply -f traffic_sim_serviceaccount.yaml

kubectl apply -f traffic_sim_clusterrole.yaml

kubectl apply -f traffic_sim_clusterolebinding.yaml

kubectl apply -f traffic_sim_cronjob.yaml

kubectl apply -f process_killer_cronjob.yaml
```

### Trouble shooting section
Often times with such a large amount of UE's deployed in the app, you may face common issues such as segementation faults.

Try restarting certain applications to get them back online and connected.

```console
kubectl rollout restart deployment ueransim-gnb -n openverso

kubectl rollout restart deployment ueransim-ues-first-batch  -n openverso

kubectl rollout restart deployment ueransim-ues-second-batch  -n openverso

kubectl rollout restart deployment ueransim-ues-third-batch  -n openverso
```

### Uninstall deployment
```console
helm uninstall open5gs
helm uninstall ueransim-gnb
helm uninstall ueransim-ues-first-batch
helm uninstall ueransim-ues-second-batch
helm uninstall ueransim-ues-third-batch
```
