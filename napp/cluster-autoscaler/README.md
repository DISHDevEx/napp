# Cluster Autoscaler

## Introduction

Cluster-autoscaler is a component that automatically adjusts the size of a Kubernetes Cluster so that all pods have a place to run and there are no unneeded nodes.  If a new pod is spun up, and waiting for scheduling, but no node in the specified node-group is available for the pod to schedule to, a new node will be spun up in the node-group to accommodate the pending pod.  Conversely, if a node in a node-group managed by cluster-autoscaler is determined to be "un-needed", after a specified time-period, the un-needed node will be spun-down and the sources freed.  This scaling is limited by the Max and Min number of nodes allowed in a node-group.

Cluster-autoscaling can be applied to any node-group. It is a feature of base Kubernetes, and can therefor be applied to essentially any cloud provider's variant of K8s.  For the purposes of this tutorial, we will be applying cluster-autoscaler to specific, not all, node-groups on a EKS Kubernetes cluster on hosted on AWS.

This tutorial will demonstrate the general process for the following:

### Topics

* [Set up an exiting node-group to enable cluster-autoscaling autodiscovery](#node-group-setup)
  * [Set the key/value pair tags for cluster-autoscaler autodiscovery](#keyvalue-pairs-to-tag-node-groups-for-cluster-autoscaling)
  * [Appropriate node-group sizing constraints when cluster-autoscaling is enabled](#example-node-group-sizing-constraints)
* [Define nodeAffinity & podAntiAffinity for specific deployments to strucutre the intereatction between deployments and node-groups with cluster-autoscaling](#nodeaffinity-and-podantiaffinity)
* [Set up Flux CD to deploy & monitor the HelmRelease of cluster-autoscaling](#flux-integration)

## Node-group Setup

The following steps will walk through the process of configuring an existing node-group for cluster-autoscaling autodiscovery.  The construction of node-groups is outside the scope of this document.

### 1. IAM Permissions

IAM permissions may need to be altered to allow the subject node-group to have the needed permissions to scale up new EC2 instances as needed.  Consult these [sample IAM policies](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md) to ensure all needed permissions exist in your current permissions.

### 2. Node-group Tags

Cluster auto-scaling takes the form of a single pod deployment on an EKS cluster.  This pod then discovers autoscaling groups by identifying node-groups with specific tags.  Each node-group you would like to have cluster-autoscaling enabled on will need the following key/value Tags:

#### Key/Value Pairs to Tag Node-Groups for Cluster-Autoscaling:
| Key                                      | Value |
|:-----------------------------------------|:-----:|
| k8s.io/cluster-autoscaler/enabled        | true  |
| k8s.io/cluster-autoscaler/<CLUSTER_NAME> | owned |

Node-group tags can be edited on the **Tags** tab on the node-group AWS Management console.  Replace ***<CLUSTER_NAME>*** with the name of your EKS cluster the subject node-group is hosted on.

### 3. Modify node-group sizing

Lastly, ensure the node-group sizing constraints suite your needs.  These can be altered on the **Details** tab on the node-group AWS Management console.  The Minimum size, Maximum size, and Desired size of the node-group will ned to be set to accommodate the needs of your project.  An example configuration is provided below for reference:

#### Example node-group sizing constraints:
| Node-group Sizing Field | Example Value |
|:------------------------|:-------------:|
| Desired size            |       2       |
| Minimum size            |       1       |
| Maximum size            |      10       |

***Note:*** cluster-autoscaling will only be able to operate within the range specified in these fields on the node-group, so ensure the Maximum size is set large enough to accommodate the max anticipated usage of the node-group.

## nodeAffinity and podAntiAffinity

nodeAffinity (or nodeAntiAffinity) and podAntiAffinity ( or podAffinity) are definable rules on all K8s deployments.  These allow for pods of a given deployment to be attracted or repelled to specific node-group(s) and/or have attraction or anti-attraction towards other pods.  For the purposes of this tutorial, we will be setting nodeAffinity for specific node-group(s) and setting podAntiAffinity such that only one UPF pod from our [***open5gs-upf***](https://github.com/open5gs/open5gs] deploymet) is deployed on each node in the specified node-group.  This allows us to direct these UPF pods towards nodes in a node-group that has cluster-autoscaling enabled to take advantage of that K8s feature.

These fields can be defined by directly modifying a Deployment Helm Chart, or dynamically modifying a Deployment through Kustomize.  In either case, these fields will need added under ```<DEPLOYMENT>.affinity```:

```yaml
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: upfInstanceSize
            operator: In
            values:
            - Large
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - upf
          topologyKey: kubernetes.io/hostname
          namespaces:
            - openverso
```
the ```matchExpressions.key``` value denotes a specific label to apply the podAntiAffinity and/or nodeAffinity to.  Labels exist on all pods from a deployment.  Both of the above rules then search for the value in the respective ```matchExpressions.key``` field, apply the ```In``` operator and search for value in ```matchExpressions.values``` to apply the ```affinity``` rule to.  

For the purposes on RESPONs and UPF scaling, these affinity rules are included in the ["custom values" file](https://github.com/DISHDevEx/napp/tree/main/napp/open5gs_values) used to Kustomize the ***Open5gs*** deployment -- specifically the ***open5gs-upf*** deployment.  These affinity rules can be modified as necisary to attract pods from any deployment to specific node-groups. 

For a more [in-depth description of these rules](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) please reference K8s documentation on ```affinity```.

## Flux Integration

***Note***:  This tutorial assumes that Flux CD and its constituent Components are already installed on the EKS cluster and running in the m-and-m namespace.

To learn more about Flux, please review the [Flux CD README](../flux/README.md) on this repo, or review [the official Flux CD documentation](https://fluxcd.io).

Instead of manually deploying the cluster-autoscaler Helm chart to the cluster, we will be letting Flux CD handle the deployment and monitoring of the cluster-autoscaler service.  The following steps walk through the process of performing this task with cluster-autoscaling, but this can be applied to nearly any K8s Deployment.

If more indepth explanation is needed, reference [the Flux CD README](../flux/README.md). 

### 1. General Flux Structure

Any K8s deployment can be monitored and deployed by Flux CD by adding it to a Flux monitored repository with a similar file hierarchy as shown below:

```console
> napp
    > napp
        > flux
            > <Desired Namespace for Flux Components>
                gotk-components.yaml
                gotk-sync.yaml
                kustomization.yaml
            <DEPLOYMENT>-ks.yaml
            <DEPLOYMENT>-src.yaml
        > <DEPLOYMENT>
            > kustomize
                kustomizeation.yaml
                kustomizeconfig.yaml
                release.yaml
                values.yaml
            README.md
```
The following yaml files can be pulled into the above file hierarchy to deploy a cluster-autoscaler Deployment in the m-and-m namespace on a EKS cluster.  When complete, the file hierarchy should look as follows:

```console
> napp
    > napp
        > flux
            > m-and-m
                gotk-components.yaml
                gotk-sync.yaml
                kustomization.yaml
            ca-ks.yaml
            ca-src.yaml
        > cluster-autoscaler
            > kustomize
                kustomizeation.yaml
                kustomizeconfig.yaml
                release.yaml
                values.yaml
            README.md
```

### 2. Define Sources

Create and populate the ```napp/flux/ca-src.yaml``` Sources with the following sources:

```yaml
---

apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: cluster-autoscaler
  namespace: m-and-m
spec:
  interval: 30s
  ref:
    branch: agent-main
  url: https://github.com/DISHDevEx/napp

---

apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cluster-autoscaler
  namespace: m-and-m
spec:
  interval: 5m
  url: https://kubernetes.github.io/autoscaler

```

### 3. Create Parent Kustomization Object

Create and populate the ```napp/flux/ca-ks.yaml``` Kustomization parent file with the following Kustomization Object:

```yaml
---

apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: cluster-autoscaler
  namespace: m-and-m
spec:
  interval: 30s
  path: ./napp/cluster-autoscaler/kustomize
  prune: true
  sourceRef:
    kind: GitRepository
    name: cluster-autoscaler
    namespace: m-and-m
  targetNamespace: m-and-m

```

### 4. Create ConfigMap Object

Create and populate the  ```napp/cluster-autoscaler/kustomizeconfig.yaml``` ConfigMap file with the following ConfigMap object:

```yaml
---

nameReference:
- kind: ConfigMap
  version: v1
  fieldSpecs:
  - path: spec/valuesFrom/name
    kind: HelmRelease

```

### 5. Create Custom Values file for Deployment

Create and populate the ```napp/cluster-autoscaler/values.yaml``` file with the following custom values to be applied to the cluster-autoscaler Deployment -- replace AWS REGION and YOUR CLUSTER NAME with the appropriate values:

```yaml
---

autoDiscovery:
  clusterName: <YOUR CLUSTER NAME>
awsRegion: <AWS REGION>

# define scale-up/scale-down times
cluster-autoscaler:
  kubernetes:
    # delay to scale down nodes after determined as "un-needed"
    # default is 10min
    io/scale-down-unneeded-time: "360s"
    # ignore any daemonset activity on node when determining if "un-needed"
    io/ignore-daemonsets-utilization: "true"

```

### 6. Create Child Kustomization Object

Create and populate the ```napp/cluster-autoscaler/kustomization.yaml``` file with the following Kustomization Object -- this object creates a Kustomization object, using the above ConfigMap and the custom values.yaml, to be applied to the cluster-autoscaler Deployment:

```yaml
---

apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - release.yaml
configMapGenerator:
  - name: cluster-autoscaler
    files:
      - values.yaml=./values.yaml
configurations:
  - kustomizeconfig.yaml
```

### 7. Create the HelmRelease Object

Create and populate the ```napp/cluster-autoscaler/release.yaml``` file with the following HelmRelease object.  Through Flux, this object deploys the Helm chart of cluster autoscaler with the above Kustomizations.

```yaml
---

apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: cluster-autoscaler
  namespace: m-and-m
spec:
  interval: 5m
  releaseName: cluster-autoscaler
  chart:
    spec:
      chart: cluster-autoscaler
      sourceRef:
        kind: HelmRepository
        name: cluster-autoscaler
        namespace: m-and-m
      interval: 5m
  valuesFrom:
    - kind: ConfigMap
      name: cluster-autoscaler
  targetNamespace: m-and-m

```

### 8. Verification

Once these changes are pushed to the remote GitHub repository, the following command can be run on the EKS cluster to ensure all Flux components are working as anticipated:

```flux get all -A```

The cluster-autoscaler pod will appear in your specified namespace (specified in the above [HelmRelease Object](#7-create-the-helmrelease-object)) with a pod name something similar to:

```cluster-autoscaler-aws-cluster-autoscaler-xxxxxxxxxx-xxxxx```
## Conclusion

With these changes in place, your chosen node-groups will perform cluster-autoscaling within the specified limits set for the group.

## Additional Resources

[Cluster-Autoscaler on ArtifactHub](https://artifacthub.io/packages/helm/cluster-autoscaler/cluster-autoscaler)

[Adding a new feature for Flux Monitoring](https://fluxcd.io/flux/get-started/)

[Cluster-autoscaler on GitHub](https://github.com/kubernetes/autoscaler)