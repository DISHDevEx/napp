# NAPP - Network as APP


## Flux CD

### Introduction to Flux

### Uses of Flux

### Installation of Flux in the *default* namespace

Flux defaults to an installation in its own namespace, *flux-system*.  vHowever, the namespace Flux is deployed within can be changed.  The following series of commands succesfully deploys Flux in the *default* namespace, but these commands can be altered to install flux into any namespace on a Kubernetes cluster.

#### Clone your repo to the local machine


#### Create path for storage of Flux CD components



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