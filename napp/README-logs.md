### NAPP - Network as APP

# Setting up Log Infrastructure

### Pre-requisites:

1. Set up your machine with the following CLI tools:
    - AWS CLI

    - Kubectl

    - Helm


2. Set up your local AWS CLI Environment Variables.

3. Create an EKS Cluster:

    Recommended settings: https://dish-wireless-network.atlassian.net/wiki/spaces/MSS/pages/427327690/Network+as+an+APP+deployment
    
4. In the sections below we are using a cluster that is named: "response_expirimentation_cluster". Feel free to replace this cluster name with your own. 


5. OpenVerso resources deployed in your cluster, 

### Deploy the Loki-Stack that includes FluentBit, Loki and Grafana:

1. Update local kubectl config file:

    ```console
    aws eks --region us-east-1 update-kubeconfig --name response_expirimentation_cluster
    ```

    (do this every time you want to talk to a new cluster)

2. Ensure your config file is set up correctly:

    ```console
    aws eks --region us-east-1 describe-cluster --name response_expirimentation_cluster --query cluster.status
    ```

3. Go to default namespace:
    
    ```console
    kubectl config set-context --current --namespace=default
    ```

4. Add Loki-Stack to helm:

    ```console
    helm repo add grafana https://grafana.github.io/helm-charts
    ```

    ```console
    helm repo update
    ```

5. Deploy Loki-Stack:

    ```console
    helm upgrade --install loki-stack grafana/loki-stack \
    --set fluent-bit.enabled=true,promtail.enabled=false,grafana.enabled=true
    ```
 
5.1 Update Values of Fluentbit and Loki:

6. Get Password in Order to Connect Loki to Grafana and copy elsewhere:

    ```console
    kubectl get secret --namespace default loki-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
    ```

7. Port Forward Grafana:

    ```console
    kubectl port-forward --namespace default service/loki-stack-grafana 3000:80
    ```

8. In your browser, go to localhost:3000 and login with:
username: admin
password: password from step 6


9. Select add first data source and use: http://loki-stack:3000/



### Deploy Kube Eagle
Pre-requisites: 
kube-metrics-server must exist. if needed, deploy in the right cluster and default namespace:
exists for prometheus but named slightly differently

    ```console
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    ```

1. Guarantee you are in the right cluster and default namespace and then add the kube-eagle helm chart:

    ```console
    helm repo add kube-eagle https://raw.githubusercontent.com/cloudworkz/kube-eagle-helm-chart/master
    ```
2. helm update:

    ```console
    helm repo update
    ```
3. Install Kube Eagle:

    ```console
    helm install kube-eagle kube-eagle/kube-eagle
    ```

### Deploy Prometheus Stack
## Pre-requisites: 
Enable OIDC for the cluster: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
1. Set up Permissions, Roles, Policies:
Create an IAM policy to attach to Role used by worker nodes OR allow S3 full permission.

    ```console
    {

    "Version": "2012-10-17",

    "Statement": [

        {

            "Sid": "Statement",

            "Effect": "Allow",

            "Action": [

                "s3:ListBucket",

                "s3:GetObject",

                "s3:DeleteObject",

                "s3:PutObject"

            ],

            "Resource": [

                "arn:aws:s3:::{s3-bucket-name}/*",

                "arn:aws:s3:::{s3-bucket-name}"

            ]

        }

    ]

}```

Create a user to authenticate the S3 bucket.
```console
Jingda will explain to me today
```

2. Alter S3 bucket configuration as needed:

```console

type: s3
config:
  bucket: <bucket_name>
  endpoint: s3.<region>.amazonaws.com
  access_key: <from user>
  secret_key: <from user>
prefix: <bucket_prefix>

```

3. Alter values file as necessary. The following edits have been made: enabled thanos sidecar creation, disabled compaction, changed retention days from 10 to 7, added prometheus operator storage config, enabled prometheus persistence and gave storage class name. 

4. Can either run the script or follow the below steps:

```console 

sh ./deploy-prometheus.sh cluster_name cluster_region cluster_namespace 

``` 

5. Create a storage class for prometheus to persist data:

```console
kubectl apply -f <prom_storage_config_filepath> -n <cluster_namespace>
```

6. Install Kube-Prometheus:

```console
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

7. Create a Secret for the S3 bucket configuration:

```console
kubectl -n <cluster_namespace> create secret generic thanos-objstore-config --from-file=thanos.yaml=<s3_storage_config_filepath>
```

8. Deploy Prometheus with Thanos Sidecar with values file to override previous values and then wait for successful creation of pods:

```console
helm install kube-prometheus -f <install_values_filepath> bitnami/kube-prometheus -n <cluster_namespace>

kubectl get pods -n <cluster_namespace> -w
```

9. Need to restart prometheus so that it operates correctly- this is because thanos sidecar attempts to read a prometheus metadata file before it is created:

```console
kubectl delete pods prometheus-kube-prometheus-prometheus-0 -n <cluster_namespace>
```

10. Confirm success of thanos-sidecar creation:

```console
kubectl logs prometheus-kube-prometheus-prometheus-0 -c thanos-sidecar -n <cluster_namespace> --tail=20
```





