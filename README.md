# NAPP - Network as an APP

## Setting up Open5gs and UERansim with 10 UE's (EKS)

### Pre-requisites:

1. Set up your machine with the following CLI tools:
    - AWS CLI

    - Kubectl

    - Helm


2. Set up your local AWS CLI Environment Variables.

3. Create an EKS Cluster:

    Recommended settings: https://dish-wireless-network.atlassian.net/wiki/spaces/MSS/pages/427327690/Network+as+an+APP+deployment
    
4. In the sections below we are using a cluster that is named: "response_expirimentation_cluster". Feel free to replace this cluster name with your own. 



5. If you already have OpenVerso resources deployed in your cluster, please clean them up and start fresh for this read me.

### Network as App deployment (please ensure you have your EKS cluster and node group fired up prior to beginning):

1. Update local kubectl config file:

    ```console
    aws eks --region us-east-1 update-kubeconfig --name response_expirimentation_cluster
    ```

    (do this every time you want to talk to a new cluster)

2. Ensure your config file is set up correctly:

    ```console
    aws eks --region us-east-1 describe-cluster --name response_expirimentation_cluster --query cluster.status
    ```

3. Create openverso namespace and set it to current namespace:
    
    ```console
    kubectl create namespace openverso
    ```
    
    ```console
    kubectl config set-context --current --namespace=openverso
    ```
    
    Troubleshooting:
    "Error from server (AlreadyExists): namespaces "openverso" already exists" 
        --> If the namespace already exists, this error will show and can be ignored.

4. Add OpenVerso to helm:

    ```console
    helm repo add openverso https://gradiant.github.io/openverso-charts/
    ```

5. Deploy open5gs, using custom values from DishDevex:

    ```console
    helm install open5gs openverso/open5gs --version 2.0.8 --values https://raw.githubusercontent.com/DISHDevEx/napp/main/napp/open5gs_values/5gSA_ues_values.yaml
    ```

6. Deploy UERANSIM, using custom values from DishDevex:

    ```console
    helm install ueransim-gnb openverso/ueransim-gnb --version 0.2.2 --values https://github.com/DISHDevEx/napp/blob/main/napp/open5gs_values/gnb_ues_values.yaml
    ```

### Ensure that your ten UE’s are set up correctly and you can enable their tunnel interfaces to connect to the internet via the network.

1. Open an interactive terminal (-ti) for the Deployment (the kubernetes load balancer) of UEs.

    ```console
    kubectl -n openverso exec -ti deployment/ueransim-gnb-ues -- /bin/bash
    ```
2. Inspect the IP addresses of the UEs.

    ```console
    ip addr
    ```
3. Verify that the deployment can communicate with the internet, in particular with google.com (replaceable with dish.com or cats.com)

    ```console
    ping -I uesimtun6 google.com
    ```
    This will ping in eternity. Please ``` ^c``` to exit the ping. 
    ```console
    traceroute -i uesimtun6 google.com
    ```
    This inspects the hops the packet from the UE took to reach google.com.
    ```console
    curl --interface uesimtun6 https://www.google.com
    ```
    This will retrieve the source code for google.com webpage. 
4. Exit the bash session and return to your local machine terminal.
    ```console
    exit
    ```

5. Ensure Mongo DB is updated:

    Enter open5gs-mongodb bash.
    ```console
    kubectl -n openverso exec deployment/open5gs-mongodb -ti -- bash
    ```
    Open MongoDB by enter the following command.
    ```console
    mongo
    ```
    Switch database to open5gs.
    ```console
    use open5gs
    ```
    Print UE information.
    ```console
    db.subscribers.find().pretty()
    ```
    To exit: (need to exit twice)
    ```console
    exit
    exit
    ```
    
6. Ensure all pods are running:

    ```console
    kubectl get pods -n openverso

    kubectl -n openverso logs deployment/ueransim-gnb
    ```


## Flux CD

View the [Flux README](napp/flux/README.md) for documentation on the installation of Flux CD and its use in NAPP.

## Cluster-Autoscaling

View the [cluster-autoscaling README](napp/cluster-autoscaler/README.md) for documentation on the implementation of cluster-autoscaling in NAPP.