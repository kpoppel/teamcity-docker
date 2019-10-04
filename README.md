# teamcity-docker
I wanted to try to setup TeamCity in a container, then run agents is Docker containers, and have those containers build me docker images.

# Step 1: TeamCity
Get Linux on a host machine
Install docker (curl https://get.docker.-com -output get_docker.sh && sh get_docker.sh)
Pull teamcity docker image
```
docker pull jetbrains/teamcity:latest
```

Start TeamCity using the scripts in teamcity directory
Setup Teamcity acount and so on.

Install the https://plugins.jetbrains.com/plugin/9306-docker-cloud/ plugin into TeamCity.

## Step 2: Agents on docker host
Next we want to run an agent in a cloud way.  On another machine get Docker setup.
Expose the TCP port (here unsecured) (https://success.docker.com/article/how-do-i-enable-the-remote-api-for-dockerd):

Create a file at /etc/systemd/system/docker.service.d/startup_options.conf

```
# /etc/systemd/system/docker.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2376
```

Reload systemd system:
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker.service
```

## Now test we can deploy a cloud agent
Create a project and add a cloud config to it:
- Server URL: point to your TeamCity host http://<ip>:8111
- Docker instance: point to your docker host: tcl://<ip>:2376
- Agent Images: Add an image for test, like jetbrains/teamcity-minimal-agent

Test the image can run.

# Step 3: Setup a docker registry.
Pull the registry.  Use he compose file: docker-registry/docker-compose-yml
Generate TLS keys.  I just wanted to use IP addresses to access the registry, which meant some more work.
If you have a DNS already setup, go for method 2.

##  Method 1 (if you want to use IP addresses):
Edit the file /etc/ssl/openssl.cnf on the registry:2 host and add
```
  [ v3_ca ]
      subjectAltName = IP:<IP of registry host>
```
or:
```
      subjectAltName = DNS:registry.mydomain.lan,IP:<IP of registry host>,IP:127.0.0.1
```

Then generate the certificates.  After the keys are generated, clean up the /etc/ssl/openssl.cnf file again.

##  Method 2 (if you have a DNS):
Do nothing

##  Generate certificates (both Method 1 and 2):
```bash
  mkdir certs
  openssl req \
    -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
    -x509 -days 365 -out certs/domain.crt
```

Be sure to use the host name like "registry.home.lan" as a CN (common name).

## Setup the docker host to use the certificates
 Linux: Copy the domain.crt file to /etc/docker/certs.d/myregistrydomain.com:5000/ca.crt on every Docker host.
 You do not need to restart Docker.
```bash
  export REGISTRY_USER=<user>
  export REGISTRY_HOST=<IP|host name>
  sudo mkdir -p /etc/docker/certs.d/10.10.10.20:5000
  sudo scp $REGISTRY_USER@$REGISTRY_HOST:/home/kpo/development/teamcity-docker/dockerfiles/docker-registry/certs/domain.crt /etc/docker/certs.d/$REGISTRY_HOST:5000/ca.crt
```

## Test the registry works
```bash
 docker pull ubuntu:16.04
 docker tag ubuntu:16.04 myregistrydomain.com/my-ubuntu
 docker push myregistrydomain.com/my-ubuntu
 docker pull myregistrydomain.com/my-ubuntu
```

At this stage you should have TeamCity, a Docker registry and a TeamCity cloud agent running.

# The docker image to generate docker images
Next up is creating a container image including the TeamCity cloud agent and docker.

## Build the image
Run the image build in tc-docker-image-builder:
```bash
docker build .
```
Once done you get something like:
  > Successfully built 9ad77dd397f7

Next tag the build and push it to the registry:
```bash
docker tag 9ad77dd397f7 <registry host|IP:5000>/tc-docker-image-builder
docker push <registry host|IP:5000>/tc-docker-image-builder
```

## Setup the image in the TeamCity cloud profile.
- Server URL: point to your TeamCity host http://<ip>:8111 (should already be set)
- Docker instance: point to your docker host: tcl://<ip>:2376 (should already be set)
- Agent Images: Add <registry host>/tc-docker-image-builder

Test the image can run

# Notes
```
#Clean up all exited containers:
docker container rm $(docker container ls -q -f 'status=exited')

#Check registry for images:
curl -k -X GET https://10.0.0.112:5000/v2/_catalog

#Check image in registry for tags:
curl -k -X GET https://10.0.0.112:5000/v2/buildtest/tags/list
```
