#!/bin/bash

## parameters
# export docker_image=mmdeploy-ci-ubuntu-18.04
export docker_image=$1


## build

docker build tests/jenkins/docker/${docker_image}/ -t ${docker_image}
container_id=$(docker run -itd ${docker_image} "/bin/bash -c git clone --recursive https://github.com/open-mmlab/mmdeploy.git") 
docker exec -d ${container_id} bash -c "/root/workspace/mmdeploy/tests/jenkins/scripts/docker_exec_for_build.sh"
