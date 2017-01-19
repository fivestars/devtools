K8S
========
This folder contains some things to get minikube setup and verify that it is working.

Get this stuff by `git clone -b k8s git@github.com:fivestars/devtools.git` from your fivestars directory and then `cd devtools/k8s`

You can run `./check_prereqs.sh` to see if you have all the necessary things installed to go wild with minikube and get our local development set up for our various projects. If you don't have some dependencies, it'll tell you where to get them from. Note, your installed dependencies must also be on your PATH.

We also have a hello-world-app, which is a simple tornado project that you can run through minikube to verify that minikube is working:
- `cd hello-world-app`
- `./minikube-hello-world-app.sh`