#!/bin/bash

#install yq for mac
brew install yq

#To get user input for cluster name, namespace, region, files:
script_name=$0
cluster_name=$1
cluster_region=$2
cluster_namespace=$3
script_full_path=$(dirname "$0")
install_values_filepath=$script_full_path/custom-prom-cm.yaml
s3_storage_config_filepath=$script_full_path/thanos-storage-config.yaml
prom_storage_config_filepath=$script_full_path/prometheus-storage-class.yaml

#Set the context for the right cluster and namespace
aws eks update-kubeconfig --region $cluster_region --name $cluster_name
kubectl config set-context --current --namespace=$cluster_namespace

#First create a prometheus storage class so that it can store data
echo "Creating a prometheus storage class with: $prom_storage_config_filepath"
kubectl apply -f $prom_storage_config_filepath -n $cluster_namespace

#Installing kube-prometheus
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

#add cluster name into filepath
export cluster_name=$cluster_name
yq e -i ".prefix= \"prometheus-metrics/$cluster_name\"" $s3_storage_config_filepath

#Creating a secret for the S3 bucket configuration
kubectl create secret generic thanos-objstore-config --from-file=thanos.yaml=$s3_storage_config_filepath

#Deploy Prometheus with Thanos Sidecar and wait for successful creation
helm upgrade --install kube-prometheus -f $install_values_filepath bitnami/kube-prometheus -n $cluster_namespace
sleep 30

#Need to restart prometheus so that it operates correctly- this is because thanos sidecar attempts to read a prometheus metadata file before it is created
kubectl delete pods prometheus-kube-prometheus-prometheus-0 -n $cluster_namespace
sleep 30

#Confirm successful deployment
kubectl get pods -n $cluster_namespace
kubectl logs prometheus-kube-prometheus-prometheus-0 -c thanos-sidecar -n $cluster_namespace --tail=20


