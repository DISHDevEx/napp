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
        > flux
```
*cd* into the *flux* directory and create *openverso-ks.yaml* and *openverso-src.yaml*
```console
cd napp/flux && touch openverso-ks.yaml openverso-src.yaml
```
You will now have two empty *.yaml* files in the *flux directory.  The naming of these files is not specific, but the location of the files within the *flux* directory is necessary. 
```console
> napp
    > napp
        > flux
            openverso-ks.yaml
            openverso-src.yaml
```
## 3. Build the *openverso-src.yaml* file

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


## 4. Build the *openverso-ks.yaml* file

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

## 5. Sign-in to Cluster

In a terminal, import AWS credentials, focus to appropriate cluster.

If desired, create a new namespace for Flux to be installed into.
```console
kubectl create namespace <namespace name>
```

## 6. Supply GitHub Token
GitHub tokens can be obtained from the DishDevEx admin.  Apply the token with the following command:
```console
export GITHUB_TOKEN=<github token>
```

## 7. Bootstrap Flux to the Kubernetes Cluster

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

## 8. Validate Installation

To validate the installation of Flux, run the following health check on the kubernetes cluster, specifying the installed namespace:
```console
flux check -n <Desired Namespace>
```
And then issue the following command to check all objects (GitObjects, and Kustomization Objects) on the cluster associated with the Flux installation:

```console
flux get all -A
```

## 9. Uninstall Flux

Flux can quickly be uninstalled, and all associated resources freed, using the following command:
```console
flux uninstall -n <Desired Namespace>
```

***Please Note***: the above command does attempt to remove the namespace that Flux is installed in.  If there are other resources in the namespace, not associated with Flux, Kubernetes will likely not allow the removal of the namespace; but it is something to keep in mind. 