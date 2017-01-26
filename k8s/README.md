K8S
========
This folder contains some things to get minikube setup and verify that it is working.

Get this stuff by `git clone -b k8s git@github.com:fivestars/devtools.git` from your fivestars directory and then `cd devtools/k8s`

You can run `./check_prereqs.sh` to see if you have all the necessary things installed to go wild with minikube and get our local development set up for our various projects. If you don't have some dependencies, it'll tell you where to get them from. Note, your installed dependencies must also be on your PATH.

We also have a hello-world-app, which is a simple tornado project that you can run through minikube to verify that minikube is working:
- `cd hello-world-app`
- `./minikube-hello-world-app.sh start`
- Once you have confirmed it is working correctly (Should get "Hello World" printed at the end of previous command), you can stop the app and clean up everything by running `./minikube-hello-world-app.sh stop`

Some helpful kubectl commands:
- `kubectl get pods` shows all the pods.
- `kubectl get svcs` shows all the services.
- `kubectl get deploys` shows all the deployments.
- `kubectl logs {pod name}` gives you the logs of a pod. Can follow the logs with the -f flag.
- `kubectl describe pod {pod name}` gives you information about the pod. Kind of like inspect in docker.
- `kubectl describe svc {svc name}` similar to above.
- `kubectl describe deploy {deploy name}` similar to above.
- `kubectl create -f {file name}` creates a kubernetes object (pod/svc/deploy) whose configuration is in {file name} yaml file.
- `kubectl delete {kubernetes object type} {kubenetes object name}` deletes the kubernetes object with that name.
- `kubectl port-forward {pod name} {local port}:{remote port}` forwards a local port to a pod.
- `kubectl apply -f {file name}` applies a configuration change if {file name} yaml file has changed.

More commands here can be found here: https://kubernetes.io/docs/user-guide/kubectl-overview/

Sometimes, minikube gets into a weird state. To get out of this you can run `minikube delete`, and then try to run the script(s) to start your project again.
