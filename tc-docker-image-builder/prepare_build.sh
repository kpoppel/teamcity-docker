#!/bin/bash
if [ -z $1 ]; then
   echo "You need to set arguments:"
   echo $0 "<teamcity host:port> <docker registry host:port>"
   echo "Try:"
   echo $0 "10.0.0.112:8111 10.0.0.112:5000"
   exit 1;
fi
TC_HOST=$1
REGISTRY_HOST=$2

rm -rf dist
wget http://$TC_HOST/update/buildAgent.zip
mkdir dist
unzip buildAgent.zip -d dist/buildagent
mv dist/buildagent/conf dist/buildagent/conf_dist

echo "Copying certificate from registry server to here"
cp ../docker-registry/certs/domain.crt ca.crt

echo "Now you can build the image:"
echo "docker build --build-arg registry_host=$REGISTRY_HOST --tag $REGISTRY_HOST/tc-docker-image-builder:latest ."
echo "docker push $REGISTRY_HOST/tc-docker-image-builder"

