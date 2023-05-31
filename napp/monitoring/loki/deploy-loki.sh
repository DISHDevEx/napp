#!/bin/bash

#To get user input for cluster name, namespace, region, files:
script_name=$0
cluster_name=$1
cluster_region=$2
cluster_namespace=$3
script_full_path=$(dirname "$0")
custom_fb_values_filepath=$script_full_path/custom-fluentbit.yaml


#Set the context for the right cluster and namespace
aws eks update-kubeconfig --region $cluster_region --name $cluster_name
kubectl config set-context --current --namespace=$cluster_namespace


#Installing loki
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo "Helm installing loki stack with loki and grafana"
helm upgrade --install loki-stack grafana/loki-stack \
    --set promtail.enabled=false,grafana.enabled=true

#Installing Fluentbit
sleep 45
echo "Retrieving loki server pod IP "
LokiHost=$(kubectl get pod loki-stack-0 --template '{{.status.podIP}}')

#create configmap
echo "Creating fluentbit configmap"
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

#deploy fluentbit
echo "Deploying fluentbit"
kubectl apply -f $custom_fb_values_filepath

#Get a secret to login to grafana
sleep 30
kubectl get secret --namespace $cluster_namespace loki-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo



