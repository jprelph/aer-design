#!/bin/bash

yum update -y
yum install -y docker
service docker start
usermod -a -G docker ec2-user

curl -O https://concourse-ci.org/docker-compose.yml
docker-compose up -d
