### NAPP - Network as APP

# Setting up Log Infrastructure

### Pre-requisites:

1. Set up your machine with the following CLI tools:
    - AWS CLI

    - Kubectl

    - Helm


2. Set up your local AWS CLI Environment Variables.
    

### Deploy Prometheus Stack
Here are links to some of the available metrics: 
- https://kubernetes.io/docs/reference/instrumentation/metrics/ 
- https://www.juniper.net/documentation/us/en/software/cn-cloud-native22/cn-cloud-native-feature-guide/cn-cloud-native-network-feature/topics/ref/cn-cloud-native-k8-metric-list.html
- You can view all available metrics by pressing the icon that resembles the earth next to where you enter you queries.


## Pre-requisites: 

1. Set up Permissions, Roles, Policies:
Create an IAM policy to attach to Role used by worker nodes.

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

    }
    ```

Create a user to authenticate the S3 bucket.

2. Alter S3 bucket configuration as needed.

```console

type: s3
config:
  bucket: <bucket_name>
  endpoint: s3.<region>.amazonaws.com
  access_key: <from user>
  secret_key: <from user>
prefix: <bucket_prefix>

```

3. Alter values file as necessary. The following edits have been made: 
-enabled thanos sidecar creation, disabled compaction, changed retention days from 10 to 7, added prometheus storage config, enabled prometheus persistence and gave storage class name, and changed scraping interval from the default 1m to 30s, removed prometheus operator and enabled prometheus to scrape node labels. We can change replicas of prometheus to 2 and sharding for better query performance in the future.

4. Follow the below steps OR utilize deploy-prometheus.sh:

```console 

sh deploy-prometheus.sh <cluster_name> <cluster_region> <cluster_namespace>

``` 

5. Create a storage class for prometheus to persist data:

```console
kubectl apply -f <prometheus_storage_class_filepath> -n <cluster_namespace>
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

11. Explore Prometheus UI:

```console
 kubectl port-forward --namespace <cluster_namespace> svc/kube-prometheus-prometheus 9090:9090
```

12. Add Prometheus to Grafana:

    12.1 Port forward grafana

```console
kubectl port-forward --namespace <cluster_namespace> service/loki-stack-grafana 3000:80
```
    12.2 Go to localhost:3000 in your browser. 
    12.3 Next add the data source- use the pod ip address of "prometheus-kube-prometheus-prometheus" in the HTTP URL: "http://<IP ADDRESS of prometheus server>:9090"
    12.4 Save and test. It should give a success message. 
    12.5 Create a networking dashboard with prometheus: 

        - Could utilize grafana dashboard Kubernetes / Networking / Pod: ID 12661

## Deploy the Loki-Stack that includes FluentBit, Loki and Grafana:

1. Update local kubectl config file:

    ```console
    aws eks --region <aws_region> update-kubeconfig --name <cluster_name>
    ```

    (do this every time you want to talk to a new cluster)

2. Set relevant namespace as context:
    
    ```console
    kubectl config set-context --current --namespace=<cluster_namespace>
    ```

3. Deploy Loki-Stack using the below directions or use deploy-loki.sh:

    ```console 
    sh deploy-loki.sh <cluster_name> <cluster_region> <cluster_namespace>
    ```

    ```console
    helm upgrade --install loki-stack grafana/loki-stack \
    --set promtail.enabled=false,grafana.enabled=true
    ```

4. Add Loki-Stack to helm:

    ```console
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    ```

5. Retrieve the IP address for the loki server:

    ```
    LokiHost=$(kubectl get pod loki-stack-0 --template '{{.status.podIP}}')
    ```

6. Create a configuration map for fluentbit:

    ```
    ClusterName=$cluster_name
    RegionName=$cluster_region
    LokiHost=$LokiHost
    FluentBitHttpPort='2020'
    FluentBitReadFromHead='Off'
    [[ ${FluentBitReadFromHead}='On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
    [[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
    kubectl create configmap fluent-bit-cluster-info \
    --from-literal=cluster.name=${ClusterName} \
    --from-literal=loki.host=${LokiHost} \
    --from-literal=http.server=${FluentBitHttpServer} \
    --from-literal=http.port=${FluentBitHttpPort} \
    --from-literal=read.head=${FluentBitReadFromHead} \
    --from-literal=read.tail=${FluentBitReadFromTail} \
    --from-literal=logs.region=${RegionName} -n $cluster_namespace 
    ```

7. Deploy fluentbit:
    ```
    kubectl apply -f $custom_fb_values_filepath
    ```

8. Get Password in Order to Connect Loki to Grafana and copy elsewhere:

    ```console
    kubectl get secret --namespace <cluster_namespace> loki-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
    ```

9. Port Forward Grafana:

    ```console
    kubectl port-forward --namespace <cluster_namespace> service/loki-stack-grafana 3000:80
    ```

10. In your browser, go to localhost:3000 and login with:
    - username: admin
    - password: <password from step 6>


11. Select add first data source and use: http://loki-stack:3100/

    - Go to the explore page and select your data source. 
    - Documentation exists here: https://grafana.com/docs/loki/latest/logql/
    - Here is an example query; {container="gnodeb"} |= "UE[111]"
    - HINTS: Edit your queries outside of grafana and paste inside- otherwise you might run into errors. Execute with shift + return. 










