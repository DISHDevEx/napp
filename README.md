# NAPP - Network as an APP


## Flux CD

### Introduction to Flux
Flux is a Continuous Delivery tool for keeping Kubernetes clusters in sync with sources of configuration (like Git repositories), and automating updates to configuration when there are new configurations to reconcile.

For further reading on Flux CD, reference the [Flux Documentation](https://fluxcd.io/flux/).

### Getting Started with Flux
#### Install Flux CLI on your Local Machine
Use the below commands based on your operating system to install the latest version of Flux CLI on your local machine.
##### macOS and Linux using Bash
```
curl -s https://fluxcd.io/install.sh | sudo bash
```
##### Windows using Chocolatey
```
choco install flux
```
##### Other Operating Systems:
For alternative installation means, visit the [Flux Documentation on Installation](https://fluxcd.io/flux/installation/#install-the-flux-cli).

### Installation of Flux in any Kubernetes namespace

Flux defaults to a deployment in its own namespace, *flux-system*.  However, Flux can be deployed in any namespace.  The following series of commands successfully deploys Flux in the *default* namespace, but these commands can be altered to install flux into any namespace on a Kubernetes cluster.

#### Clone your repo to the local machine
Clone your *napp* repository to your local machine

#### Generate the *gotk-components.yaml* 
This *gotk-components.yaml* file is used to generate all the Flux Controllers when applied to the cluster.
```
flux install \
  --namespace="default" \
  --export > ./napp/flux/gotk-components.yaml
```

#### Commit changes to repo
```
git add -A && git commit -m "add flux components" && git push
```

#### Apply the *gotk-components.yaml* file to the cluster
```
kubectl apply -f ./napp/flux/gotk-components.yaml
```

#### Ensure the Flux health check passes with no errors
```
flux check --namespace="default"
```

#### Create a GitRepository object on the cluster
```
flux create source git napp \
  --url=https://github.com/DISHDevEx/napp.git \
  --branch=pierce/flux \
  --interval=1m \
  --namespace="default"
```

#### Create a Kustomization object on the cluster
```
flux create kustomization napp \
  --source=napp \
  --path="./napp/flux/" \
  --prune=true \
  --interval=10m \
  --namespace="default"
```

#### Export the Kustomization and GitRepository objects to *gotk-sync.yaml*
```
flux export source git napp \
  > ./napp/flux/gotk-sync.yaml \
  --namespace="default"

flux export kustomization napp \
  >> ./napp/flux/gotk-sync.yaml \
  --namespace="default"
```

#### Create the *kustomization.yaml* file
```
cd ./napp/flux && kustomize create --autodetect
```

#### Commit and push *kustomization.yaml* and synce manifests to repo
```
git add -A && git commit -m "add sync manifests files" && git push
```