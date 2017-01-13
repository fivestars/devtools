#! /usr/bin/env bash

echo Checking if necessary requirements are installed for minikube...
vboxmanage >/dev/null
if [ $? -eq 0 ]; then
    echo VirtualBox is installed with v$(vboxmanage --version)
else
    echo Please install VirtualBox from https://www.virtualbox.org/wiki/Downloads 
fi

docker >/dev/null
if [ $? -eq 0 ]; then
    echo -e Docker is installed with v$(docker --version | grep -o -m 1 '\d*\.\d*\.\d*')
else
    echo Please install VirtualBox from https://docs.docker.com/engine/installation/ 
fi

minikube >/dev/null
if [ $? -eq 0 ]; then
    echo Minikube is installed with $(minikube version | grep -o -m 1 'v\d*\.\d*\.\d*')
else
    echo Please install Minikube from https://github.com/kubernetes/minikube/releases 
fi

kubectl >/dev/null
if [ $? -eq 0 ]; then
    echo Kubectl is installed with $(kubectl version | grep -o -m 1 'v\d*\.\d*\.\d*') Need at least v1.0.0
else
    echo Please install Kubectl from https://kubernetes.io/docs/getting-started-guides/kubectl/
fi

git --version>/dev/null
if [ $? -eq 0 ]; then
    echo Git is installed with v$(git --version | grep -o '\d\.\d\.\d')
else
    echo Please install git from https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
fi

aws help >/dev/null
if [ $? -eq 0 ]; then
    echo Aws-cli is installed 
else
    echo Please install aws-cli from http://docs.aws.amazon.com/cli/latest/userguide/installing.html 
fi
