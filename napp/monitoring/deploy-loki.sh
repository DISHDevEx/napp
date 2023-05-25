#!/bin/bash

#install yq for mac
brew install yq

#To get user input for cluster name, namespace, region, files:
script_name=$0
cluster_name=$1
cluster_region=$2
cluster_namespace=$3
script_full_path=$(dirname "$0")
install_values_filepath=$script_full_path/custom_cm.yaml


#Set the context for the right cluster and namespace
aws eks update-kubeconfig --region $cluster_region --name $cluster_name
kubectl config set-context --current --namespace=$cluster_namespace


#Installing loki
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install loki-stack grafana/loki-stack \
    --set promtail.enabled=false,grafana.enabled=true

#update loki to include other types of logs

#helm upgrade loki-stack -f $install_values_filepath grafana/loki-stack -n $cluster_namespace


#Get a secret to login to grafaana
sleep 30
kubectl get secret --namespace $cluster_namespace loki-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo



