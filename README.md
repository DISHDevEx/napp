# NAPP - Network as an APP

# Setting up Open5gs and UERansim with 10 UE's (EKS)

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
    helm install open5gs openverso/open5gs --version 2.0.8 --values https://raw.githubusercontent.com/DISHDevEx/openverso-charts/master/charts/respons/5gSA_ues_values.yaml
    ```

6. Deploy UERANSIM, using custom values from DishDevex:

    ```console
    helm install ueransim-gnb openverso/ueransim-gnb --version 0.2.2 --values https://raw.githubusercontent.com/DISHDevEx/openverso-charts/master/charts/respons/gnb_ues_values.yaml
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

### Getting Started with Flux
Use the below commands based on your operating system to install the latest version of Flux CLI on your local machine.
#### macOS and Linux using Bash
```console
curl -s https://fluxcd.io/install.sh | sudo bash
```
#### Windows using Chocolatey
```console
choco install flux
```
#### Other Operating Systems:
For alternative installation means, visit the [Flux Documentation on Installation](https://fluxcd.io/flux/installation/#install-the-flux-cli).




### Installation of Flux in any Kubernetes namespace

Flux defaults to a deployment in its own namespace, *flux-system*.  However, Flux can be deployed in any namespace by specifying the *--namespace* flag during the bootstrap process.  The following tutorial will walk through the process of creating a custom namespace, creating the Kustomization and Sources yaml files for Flux reconciliation, installing flux into the namespace, and validating the installation. For testing purposes, always work with-in your own branch and adhere to the pull-request process prior to committing to the main branch.

#### 1. Clone your repo and create a branch
Clone *napp* repository to your local machine and *cd* into the repo
```console
git@github.com:DISHDevEx/napp.git && cd napp
```
Checkout a branch
```console
git branch <first_name/feature_name> && git checkout <first_name/feature_name>
```

### 2. Navigate into the Flux directory & create Kustomization and Sources yaml files
Flux CD is to be installed on the Kubernetes cluster of your choice, but the configuration files (covered later) and the Kustomization and Source yaml files will live on a git repository.  For the rest of this tutorial, we will be working in the *napp/napp/flux* directory:
```console
> napp
    > napp
        > flux
```
*cd* into the *flux* directory and create *openverso-ks.yaml* and *openverso-src.yaml*
```console
cd napp/napp/flux && touch openverso-ks.yaml openverso-src.yaml
```
You will now have two empty *.yaml* files in the *flux directory.  The naming of these files is not specific, but the location of the files within the *flux* directory is necessary. 
```console
> napp
    > napp
        > flux
            openverso-ks.yaml
            openverso-src.yaml
```
### 3. Build the *openverso-src.yaml* file

**Note**: for simplicity, this tutorial is assuming that the following objects will be stored in the ***openverso*** namespace, so that these objects live next to the 5G core deployment.  If a different namespace is needed, specify it in the *.yaml* content in both the *openverso-src.yaml* and *openverso-ks.yaml* files.

The *spec* field specifies the repository and branch that will be monitored by Flux for changes, as well as the interval that the repository is checked.  If multiple sources are desired to be reconciled against the Kubernetes cluster, than the below *.yaml* file can be replicated in the same *openverso-src.yaml* file to add additional sources.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: <desired name of GitRepository object>
  namespace: openverso
spec:
  interval: 30s
  ref:
    branch: <branch name>
  url: https://github.com/DISHDevEx/openverso-charts
```

For more information on this process, reference the [Flux Documentation](https://fluxcd.io/flux/guides/helmreleases/#refer-to-values-in-configmaps-generated-with-kustomize) or the [Kubernetes Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/).


### 4. Build the *openverso-ks.yaml* file

**Note**: for simplicity, this tutorial is assuming that the following objects will be stored in the ***openverso*** namespace, so that these objects live next to the 5G core deployment.  If a different namespace is needed, specify it in the *.yaml* content in both the *openverso-src.yaml* and *openverso-ks.yaml* files.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: open5gs
  namespace: openverso
spec:
  interval: 30s
  path: ./charts/kustomize
  prune: true
  sourceRef:
    kind: GitRepository
    name: <name of GitRepository object declared in openverso-src.yaml>
    namespace: openverso
  targetNamespace: openverso
```
For more information on this process, reference the [Flux Documentation](https://fluxcd.io/flux/guides/helmreleases/#refer-to-values-in-configmaps-generated-with-kustomize) or the [Kubernetes Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/).

### 5. Sign-in to Cluster

In a terminal, import AWS credentials, focus to appropriate cluster.

If desired, create a new namespace for Flux to be installed into.
```console
kubectl create namespace <namespace name>
```

### 6. Supply GitHub Token
GitHub tokens can be obtained from the DishDevEx admin.  Apply the token with the following command:
```console
export GITHUB_TOKEN=<github token>
```

### 6. Bootstrap Flux to the Kubernetes Cluster

The following bootstrap command will generate the *.yaml* files needed to install Flux; these *.yaml* files are then stored in GitHub on the specified repository, branch, and path.  The bootstrap command then automatically applies these *.yaml* files to the Kubernetes cluster.  

```console
flux bootstrap github \
  --namespace=<Desired Namespace> \
  --owner=<Github Organization Name> \
  --repository=<Name of Repository> \
  --branch=<Branch Name (defaults to *main*)> \
  --path=<Path to *flux* directory in repository
```

Once this command is executed and complete, the GitHub repository structure will look as follows:

```console
> napp
    > napp
        > flux
            > <Desired Namespace>
                gotk-components.yaml
                gotk-sync.yaml
                kustomization.yaml
            openverso-ks.yaml
            openverso-src.yaml
```

### 7. Validate Installation

To validate the installation of Flux, run the following health check on the kubernetes cluster, specifying the installed namespace:
```console
flux check -n <Desired Namespace>
```
And then issue the following command to check all objects (GitObjects, and Kustomization Objects) on the cluster associated with the Flux installation:

```console
flux get all -A
```

### 8. Uninstallation

Flux can quickly be uninstalled, and all associated resources freed, using the following command:
```console
flux uninstall -n <Desired Namespace>
```

***Please Note***: the above command does attempt to remove the namespace that Flux is installed in.  If there are other resources in the namespace, not associated with Flux, Kubernetes will likely not allow the removal of the namespace; but it is something to keep in mind. 