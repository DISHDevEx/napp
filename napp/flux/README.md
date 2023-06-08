# Flux CD

## Table of Contents
- [Installing Flux on Your Machine](#getting-started-with-flux)
- [Managing a K8s Deployment with Flux](#managing-a-k8s-deployment-with-flux-cd)
- [Suspend and Resume Flux Reconciliation](#suspend-and-resume-flux-reconciliation)

## Getting Started with Flux
Use the below commands based on your operating system to install the latest version of Flux CLI on your local machine.
### macOS and Linux using Bash
```console
brew install fluxcd/tap/flux
```
### Windows using Chocolatey
```console
choco install flux
```
### Other Operating Systems:
For alternative installation means, visit the [Flux Documentation on Installation](https://fluxcd.io/flux/installation/#install-the-flux-cli).




## Managing a K8s Deployment with Flux CD

The following tutorial will walk through the process of deploying and managing an Open5gs deployment using Flux CD and the NAPP repo.  However, this process can be applied to almost any K8S Deployment to hand of the deployment and management of a Deployment to Flux CD.  

### 1. Clone your repo and create a branch
Clone *NAPP* repository to your local machine and *cd* into the repo
```console
git@github.com:DISHDevEx/napp.git && cd napp
```
Checkout a branch
```console
git branch <first_name/feature_name> && git checkout <first_name/feature_name>
```

### 2. Navigate into the Flux directory & create Kustomization and Sources yaml files
For every separate Deployment Flux CD is to manage, define a Kustomization and Sources yaml file in the Flux Directory:
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
### 3. Build the *openverso-src.yaml* file

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


### 4. Build the *openverso-ks.yaml* file

Flux reconciles using Kustomization objects.  This files creates the parent Kustomization object and directs Flux towards the **kustomization** sources for the cluster.  The *./napp/open5g2_values/kustomize* directory and contained files are built out in following steps.

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
### 5. Navigate to ***open5gs_values***
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

### 6. Generate files in *kustomize* directory

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
### 7. Build the *kustomization.yaml* file

A *Kustomization* object allows you to apply custom values to a Helm Release on your cluster.  For the *kustomization.yaml* file, use the below .yaml file and point the **configMapGenerator/files/values.yaml** field towards the custom value file of your choosing.  If an entire directory is to be reconciled, then direct this same field to a directory. 

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
  - kustomizeconfig.yaml
```

### 8. Build the *kustomizeconfig.yaml* file 
Build the *kustomizeconfig.yaml* file using the following yaml example:
```yaml
nameReference:
- kind: ConfigMap
  version: v1
  fieldSpecs:
  - path: spec/valuesFrom/name
    kind: HelmRelease
```
This file creates a ConfigMap object used in applying the Kustomization object with the custom values.yaml file above to the Deployment.

### 9. Build the *release.yaml* file 

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
### 10. Sign-in to Cluster

In a terminal, import AWS credentials, focus to appropriate cluster.

If desired, create a new namespace for Flux to be installed into.
```console
kubectl create namespace <namespace name>
```

### 11. Supply GitHub Token
GitHub tokens can be obtained from the DishDevEx admin.  Apply the token with the following command:
```console
export GITHUB_TOKEN=<github token>
```

### 12. Bootstrap Flux to the Kubernetes Cluster

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
            > kustomize
                kustomizeation.yaml
                kustomizeconfig.yaml
                release.yaml
```

If you would like to set up an additional Deployment to be deployed and managed by Flux, the general folder hierarchy for a Deployment is as follows:

```console
> napp
    > napp
        > flux
            > <Desired Namespace for Flux Components>
                gotk-components.yaml
                gotk-sync.yaml
                kustomization.yaml
            * <DEPLOYMENT>-ks.yaml
            * <DEPLOYMENT>-src.yaml
            openverso-ks.yaml
            openverso-src.yaml
        > <DEPLOYMENT>
            > kustomize
                kustomizeation.yaml
                kustomizeconfig.yaml
                release.yaml
                values.yaml
            README.md
        > open5gs_values
            > kustomize
                kustomizeation.yaml
                kustomizeconfig.yaml
                release.yaml
```

### 13. Validate Installation

To validate the installation of Flux, run the following health check on the kubernetes cluster, specifying the installed namespace:
```console
flux check -n <Desired Namespace>
```
And then issue the following command to check all objects (GitObjects, and Kustomization Objects, ConfigMap Object, etc) on the cluster associated with the Flux installation and the above *.yaml* files:

```console
flux get all -A
```

### 14. Clean-up

Flux can quickly be uninstalled, and all associated resources freed, using the following command:
```console
flux uninstall --keep-namespace -n <Desired Namespace>
```

## Suspend and Resume Flux Reconciliation

### Suspend Flux Reconciliation
At times, it may be useful to Suspend the monitoring and reconciliation of a specific aspect of Flux.  This can be accomplished by the use of ***suspend*** sub-command in Flux:
```console
flux suspend [command]
```
***Note:*** at anytime, ```flux --help``` or ```flux suspend --help``` can be used to give suggestion from Flux on how to proceed.

The *[command]* field above can be replaced with any of the following Available Command options:

- alert
- helmrelease
- image
- kustomization
- receiver
- source

For the purposes of NAPP and m-and-m, you will likely be looking to use the ***helmrelease*** command.  

#### Example Use Case 
As a developer, you would like to delete the **open5gs** Helm Deployment from a Flux managed cluster.  You would like to re-deploy **open5gs** with some different configurations.  However, when you simply issue ```helm uninstall open5gs```, Flux reconciles and redeploys **open5gs** within 30seconds (due to Flux settings).  This is a perfect use case for ```flux suspend```.

Issue the following command to suspend / pause the reconciliation of the **open5gs** Helmrelease:

```console
flux suspend helmrelease open5gs -n <NAMESPACE_CONTAINING_OPEN5GS>
```
The **open5gs** deployment can now be removed and manipulated as you wish, without Flux reconciling and reinstalling every specified time interval.  The behaviour will persist until the [resume](#resume-flux-reconciliation) sub-command is issued.

### Resume Flux Reconciliation

To Resume reconciliation of an aspect of Flux that was previously Suspended, issue the following command:

```console
flux resume [command] <SUSPENDED_SERVICE> -n <NAMESPACE_OF_SUSPENDED_SERVICE>
```

For example, if **open5gs** was suspended as given in the [example above](#suspend-and-resume-flux-reconciliation), then the associated Resume command would be as follows:

```console
flux resume helmrelease open5gs -n <NAMESPACE_CONTAINING_OPEN5GS>
```