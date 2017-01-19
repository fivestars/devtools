#! /usr/bin/env bash


timestamp() {
  echo Current Time is $(date +"%T")
}

cmd=${1:-start}

case $cmd in
    start)
		PS3="Select your OS [Mac/Windows]: "
		options=("Mac" "Windows")
		select opt in "${options[@]}"; do
		    case $opt in
		        "${options[0]}") OS="$opt"; break ;;
		        "${options[1]}") OS="$opt"; break ;;
		        *) printf "Choose a valid option $opt\n" ;;
		    esac
		done
		timestamp
		echo "Starting Minikube... (~75 seconds)"
		if ! (  minikube status | grep Running > /dev/null ); then
			minikube start  &>/dev/null
		fi
		eval $(minikube docker-env) &>/dev/null
		echo Minikube Started
		timestamp
		echo "Building hello-world-app docker image... (~ 90 seconds)"
		if ! [[ $(docker images -q hello-world-app:dev) ]]; then
			docker build -t hello-world-app:dev . &>/dev/null
		fi
		echo Docker Image Built
		timestamp
		echo "Creating Kubernetes Persistent Volume and Claim objects... (fast)"
		if [[ $OS == "Mac" ]]; then
			kubectl create -f pv-mac.yaml
		elif [[ $OS == "Windows" ]]; then
			kubectl create -f pv-windows.yaml
		else 
			echo Error in your OS choice 
			exit 1
		fi
		kubectl create -f pvc.yaml
		timestamp
		echo "Creating hello-world-app deploy... (fast)"
		kubectl create --validate=false -f deploymentConfig.yaml
		timestamp
		echo "Exposing hello-world-app service... (fast)"
		kubectl expose deployment hello-world-app --name=hello-world-app --type=NodePort
		timestamp
		echo Sleeping for 10 seconds before checking service is up and running...
		sleep 10 # Let service get up and running before curling
		endpoint=$(minikube ip)$(kubectl get svc | grep hello-world-app | egrep -o ':\d{5}')
		echo Curling ${endpoint}, which is where your hello world app is. 
		echo Expecting: 
		echo Hello World
		echo Got:
		curl ${endpoint}
		echo 
		timestamp
		;;
	stop)
		timestamp
		echo Deleting hello-world-app deploy if it is there...
		kubectl delete deploy hello-world-app &>/dev/null
		echo Deleted hello-world-app deploy
		echo Deleting hello-world-app service if it is there...
		kubectl delete svc hello-world-app &>/dev/null
		echo Deleted hello-world-app service
		echo Deleting hello-world-app persistent volume and claim objects if they are there...
		kubectl delete pv hello-world-app-persistent-volume &>/dev/null
		kubectl delete pvc hello-world-app-persistentclaim &>/dev/null
		echo Deleted hello-world-app persistent volume and claim objects
		timestamp
		;;
	*)
		echo "Invalid command: $cmd" >&2;
        exit 1
        ;;
esac