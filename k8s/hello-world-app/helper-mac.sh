#! /usr/bin/env bash

minikube start
eval $(minikube docker-env)
docker build -t hello-world-app:dev .
kubectl create -f pv-mac.yaml
kubectl create -f pvc.yaml
kubectl create --validate=false -f deploymentConfig.yaml
kubectl expose deployment hello-world-app --name=hello-world-app --type=NodePort
sleep 10 # Let service get up and running before curling
endpoint=$(minikube ip)$(kubectl get svc | grep hello-world-app | egrep -o ':\d{5}')
echo curling ${endpoint}, which is where your hello world app is. Expecting Hello World
curl ${endpoint}
echo 
