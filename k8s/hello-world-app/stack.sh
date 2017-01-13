docker service ps hello-world &>/dev/null || 
    docker service create --with-registry-auth \
        --name hello-world \
        --mount type=bind,src=/Users/fivestars.user/fivestars/hello-world-app,dst=/home/fivestars/hello-world-app \
        --publish 7892:7892 \
        hello-world-app:dev