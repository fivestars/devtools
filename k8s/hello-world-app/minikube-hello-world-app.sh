#! /usr/bin/env bash


timestamp() {
  echo Current Time is $(date +"%T")
}

cmd=${1:-start}

case $cmd in
    start)
		timestamp
		echo "Starting Minikube if not already started... (~75 seconds)"
		if ! (  minikube status | grep Running > /dev/null ); then
			minikube start  &>/dev/null
		fi
		eval $(minikube docker-env) &>/dev/null
		echo Minikube Started
		echo
		timestamp
		echo "Building hello-world-app docker image if not already built... (~ 90 seconds)"
		if ! [[ $(docker images -q hello-world-app:dev) ]]; then
			docker build -t hello-world-app:dev . &>/dev/null
		fi
		echo Docker Image Built
		echo
		timestamp
		echo "Creating Kubernetes Persistent Volume and Claim objects... (fast)"
		sed -e "s;%PATH%;$(pwd);g" pv.yaml.template > pv.yaml
		kubectl create -f pv.yaml
		kubectl create -f pvc.yaml
		echo
		timestamp
		echo "Creating hello-world-app deploy... (fast)"
		kubectl create --validate=false -f deploymentConfig.yaml
		echo
		timestamp
		echo "Exposing hello-world-app service... (fast)"
		kubectl expose deployment hello-world-app --name=hello-world-app --type=NodePort
		echo
		timestamp
		echo Sleeping for 10 seconds before checking service is up and running...
		sleep 10 # Let service get up and running before curling
		echo
		endpoint=$(minikube ip)$(kubectl get svc | grep hello-world-app | egrep -o ':\d{5}')
		echo Curling ${endpoint}, which is where your hello world app is. 
		echo "Expecting:" 
		echo "Hello World"
		echo "Got:"
		curl ${endpoint}
		echo 
		timestamp
		;;
	stop)
		echo Deleting hello-world-app deploy if it is there...
		kubectl delete deploy hello-world-app &>/dev/null
		echo Deleted hello-world-app deploy
		echo
		echo Deleting hello-world-app service if it is there...
		kubectl delete svc hello-world-app &>/dev/null
		echo Deleted hello-world-app service
		echo
		echo Deleting hello-world-app persistent volume and claim objects if they are there...
		kubectl delete pv hello-world-app-persistent-volume &>/dev/null
		kubectl delete pvc hello-world-app-persistentclaim &>/dev/null
		echo Deleted hello-world-app persistent volume and claim objects
		;;
	*)
		echo "Invalid command: $cmd" >&2;
        exit 1
        ;;
esac