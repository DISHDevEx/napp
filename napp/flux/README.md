# Flux CD

## Getting Started with Flux
Use the below commands based on your operating system to install the latest version of Flux CLI on your local machine.
### macOS and Linux using Bash
```console
curl -s https://fluxcd.io/install.sh | sudo bash
```
### Windows using Chocolatey
```console
choco install flux
```
### Other Operating Systems:
For alternative installation means, visit the [Flux Documentation on Installation](https://fluxcd.io/flux/installation/#install-the-flux-cli).




## Installation of Flux in any Kubernetes namespace

Flux defaults to a deployment in its own namespace, *flux-system*.  However, Flux can be deployed in any namespace by specifying the *--namespace* flag during the bootstrap process.  The following tutorial will walk through the process of creating a custom namespace, creating the Kustomization and Sources yaml files for Flux reconciliation, installing flux into the namespace, and validating the installation. For testing purposes, always work with-in your own branch and adhere to the pull-request process prior to committing to the main branch.

### 1. Clone your repo and create a branch
Clone *napp* repository to your local machine and *cd* into the repo
```console
git@github.com:DISHDevEx/napp.git && cd napp
```
Checkout a branch
```console
git branch <first_name/feature_name> && git checkout <first_name/feature_name>
```

## 2. Navigate into the Flux directory & create Kustomization and Sources yaml files
Flux CD is to be installed on the Kubernetes cluster of your choice, but the configuration files (covered later) and the Kustomization and Source yaml files will live on a git repository.  For the rest of this tutorial, we will be working in the *napp/napp/flux* directory:
```console
> napp
    > napp
        * flux
        > open5gs_values
```
*cd* into the *flux* directory and create *openverso-ks.yaml* and *openverso-src.yaml*
```console
cd napp/flux && touch openverso-ks.yaml openverso-src.yaml
```
You will now have two empty *.yaml* files in the *flux directory.  The naming of these files is not specific, but the location of the files within the *flux* directory is necessary. 
```console
> napp
    > napp
        * flux
            openverso-ks.yaml
            openverso-src.yaml
        > open5gs_values
```
## 3. Build the *openverso-src.yaml* file

**Note**: for simplicity, this tutorial is assuming that the following objects will be stored in the ***openverso*** namespace, so that these objects live next to the 5G core deployment.  If a different namespace is needed, specify it in the below *.yaml* files.  It is further assumed that there is a need for two sources; one for the open5gs Helm deployment (pulled from [Gradiant/openverso-charts](https://github.com/Gradiant/openverso-charts)), and one source on the [DISHDevEx/napp](https://github.com/DISHDevEx/napp/tree/agent-main/napp/open5gs_values) for storing the custom values applied to the Gradiant/openverso-charts deployment.

The *spec* field specifies the repository and branch that will be monitored by Flux for changes, as well as the interval that the repository is checked.  If multiple sources are desired to be reconciled against the Kubernetes cluster, than the below *.yaml* file can be replicated in the same *openverso-src.yaml* file to add additional sources.  For this example, the two sources Noted above are used.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: openverso-custom-values
  namespace: openverso
spec:
  interval: 30s
  ref:
    branch: agent-main
  url: https://github.com/DISHDevEx/napp/tree/agent-main/napp/open5gs_values

---

apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: gradiant-openverso-charts
  namespace: openverso
spec:
  interval: 30s
  ref:
    branch: master
  url: https://github.com/Gradiant/openverso-charts
```

For more information on this process, reference the [Flux Documentation](https://fluxcd.io/flux/guides/helmreleases/#refer-to-values-in-configmaps-generated-with-kustomize) or the [Kubernetes Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/).


## 4. Build the *openverso-ks.yaml* file

This files directs Flux towards the **kustomization** sources for the cluster.  The *./napp/open5g2_values/kustomize* directory and contained files are built out in following steps.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: open5gs
  namespace: openverso
spec:
  interval: 30s
  path: ./napp/open5gs_values/kustomize
  prune: true
  sourceRef:
    kind: GitRepository
    name: openverso-custom-values
    namespace: openverso
  targetNamespace: openverso
```
## 5. Navigate to ***open5gs_values***
Next, navigate to the *open5gs_values* directory 
```console
> napp
    > napp
        > flux
        * open5gs_values
            > kustomize
              VALUES.yaml
```
***NOTE:*** In this directory, there are several *VALUES.yaml* files -- these are ConfigMap files that can be applied to the open5gs deployment on the cluster. Flux can be configured to either reconcile a single file, a whole directory, or entire repository against a K8s cluster.  As shown in the **openverso-src.yaml** above, this deployment of Flux is looking at two repositories -- the Gradiant/openverso-charts repository and the DISHDevEx/napp repository.  For the first repository, Gradiant/openverso-charts, the entire reposiory is being reconciled.  For the second source, DISHDevEx/napp, only a portion of the repository will be reconciled; specificaly, the *open5gs_values/kusomize/VALUES.yaml* file will be reconciled.  However, the following files can be modified to reconcile the entire *ope5gs_values/kustomize* directory. 

## 6. Generate files in *kustomize* directory

Issue the following command:

```console
cd kustomize && touch kustomization.yaml kustomizeconfig.yaml release.yaml
```
There will now be three blank yaml files in the *kustomize* directory:
```console
> napp
    > napp
        > flux
        * open5gs_values
            > kustomize
                kustomization.yaml
                kustomizeconfig.yaml
                release.yaml
              VALUES.yaml
```
## 7. Build the *kustomization.yaml* file

A *Kustomization* object allows you to apply custom values to a Helm Release on your cluster.  For the *kustomization.yaml* file, use the below .yaml file and point the **configMapGenerator/files/values.yaml** feild towards the custom value file of your choosing.  If an entire directory is to be reconciled, then direct this same feild to a directory. 

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - release.yaml
configMapGenerator:
  - name: custom-values
    files:
      - values.yaml=../VALUES.yaml
configurations:
  - ca-kustomizeconfig.yaml
```

## 8. Build the *kustomizeconfig.yaml* file 
Build the *kustomizeconfig.yaml* file using the following yaml example:
```yaml
nameReference:
- kind: ConfigMap
  version: v1
  fieldSpecs:
  - path: spec/valuesFrom/name
    kind: HelmRelease
```

## 9. Build the *release.yaml* file 

Build the *release.yaml* file using the yaml example below.  This will create the Helm release on the cluster.  Note, the *chart* is being pulled from the **Gradiant/openverso-charts** source, while the *valuesFrom* is being pulled from the **custom-values** ConfigMap object which references the **DISHDevEx/napp** repo and pulls on the custom values held in **open5gs_values**. 

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: open5gs
  namespace: openverso
spec:
  interval: 30s
  releaseName: open5gs-gradiant
  chart:
    spec:
      chart: ./charts/open5gs
      sourceRef:
        kind: GitRepository
        name: gradiant-openverso-charts
        namespace: openverso
  valuesFrom:
    - kind: ConfigMap
      name: custom-values
  targetNamespace: openverso
```
## 10. Sign-in to Cluster

In a terminal, import AWS credentials, focus to appropriate cluster.

If desired, create a new namespace for Flux to be installed into.
```console
kubectl create namespace <namespace name>
```

## 11. Supply GitHub Token
GitHub tokens can be obtained from the DishDevEx admin.  Apply the token with the following command:
```console
export GITHUB_TOKEN=<github token>
```

## 12. Bootstrap Flux to the Kubernetes Cluster

The following bootstrap command will generate the *.yaml* files needed to install Flux; these *.yaml* files are then stored in GitHub on the specified repository, branch, and path.  The bootstrap command then automatically applies these *.yaml* files to the Kubernetes cluster.  

```console
flux bootstrap github \
  --namespace=<Desired Namespace> \
  --owner=<Github Organization Name> \
  --repository=<Name of Repository> \
  --branch=<Branch Name (defaults to *main*)> \
  --path=<Path to *flux* directory in repository>
```

Once this command is executed and complete, the GitHub repository structure will look as follows with the generated Flux yaml files:

```console
> napp
    > napp
        * flux
            > <Desired Namespace>
                gotk-components.yaml
                gotk-sync.yaml
                kustomization.yaml
            openverso-ks.yaml
            openverso-src.yaml
        > open5gs_values
```

## 13. Validate Installation

To validate the installation of Flux, run the following health check on the kubernetes cluster, specifying the installed namespace:
```console
flux check -n <Desired Namespace>
```
And then issue the following command to check all objects (GitObjects, and Kustomization Objects, ConfigMap Object, etc) on the cluster associated with the Flux installation and the above *.yaml* files:

```console
flux get all -A
```

## 14. Clean-up

Flux can quickly be uninstalled, and all associated resources freed, using the following command:
```console
flux uninstall --keep-namespace -n <Desired Namespace>
```