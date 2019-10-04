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
Expose the TCP port (here unsecured port) (https://success.docker.com/article/how-do-i-enable-the-remote-api-for-dockerd):

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
- Agent Images: jetbrains/teamcity-minimal-agent

Test the image can run.

At this point you can crate a simple build configuration to run e.g. 'ls' or 'du /' in the docker agent.
Not very useful though...

# Step 3: Setup a docker registry.
To get some more meat on the bone we need a registry to save newly generated containers to.

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
      subjectAltName = DNS:myregistrydomain.com,IP:<IP of registry host>,IP:127.0.0.1
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
  sudo mkdir -p /etc/docker/certs.d/$REGISTRY_HOST:5000
  sudo scp $REGISTRY_USER@$REGISTRY_HOST:/home/kpo/development/teamcity-docker/dockerfiles/docker-registry/certs/domain.crt /etc/docker/certs.d/$REGISTRY_HOST:5000/ca.crt
```

## Test the registry works
```bash
 docker pull ubuntu:16.04
 docker tag ubuntu:16.04 $REGISTRY_HOST/my-ubuntu
 docker push myregistrydomain.com/my-ubuntu
 docker pull myregistrydomain.com/my-ubuntu
```

At this stage you should have TeamCity, a Docker registry and a TeamCity cloud agent running.

# The docker image to generate docker images
Next up is creating a container image including the TeamCity cloud agent and docker.

Run the image build in tc-docker-image-builder:
```bash
prepare.sh
```
Just follow what it says on the screen.

## Setup the image in the TeamCity cloud profile.
- Server URL: point to your TeamCity host http://<ip>:8111 (should already be set)
- Docker instance: point to your docker host: tcl://<ip>:2376 (should already be set)
- Agent Images: Add <registry host>/tc-docker-image-builder

Test the image can run and decomission it.

## Let us use the image to build something
In TeamCity setup a build configuration:

Build Step	Parameters Description
1. Build        Docker (BUILD)
                Docker build; Dockerfile content provided in directly in build step
                Execute: If all previous steps finished successfully
                Image Name:tag : <registry host>/buildtest:%build.number%
 
2. Push         Docker (PUSH)
                docker push 10.0.0.112:5000/buildtest:%build.number%; remove image(s) after push
                Execute: If all previous steps finished successfully
                Image Name:tag : <registry host>/buildtest:%build.number%

Use for example this content for the test (yes it builds another teamcity docker agent):
```
FROM jetbrains/teamcity-minimal-agent:latest

LABEL dockerImage.teamcity.version="latest" \
      dockerImage.teamcity.buildNumber="latest"

RUN apt-get update && \
    apt-get install -y git apt-transport-https ca-certificates software-properties-common && \
    \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    \
    apt-cache policy docker-ce && \
    apt-get update && \
    apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu systemd && \
    \
    \
    rm -rf /var/lib/apt/lists/* && \
    \
    apt-get clean all && \
    \
    usermod -aG docker buildagent
VOLUME /var/lib/docker
```

Add "Build features" -> "Docker support".  This is not strictly necessary, but it adds a nive tab with the docker result
to the build result screen. I checked cleanup the server checkbutton.

Save the build configuration.

## Running the build
Press run. This is what is supposed to happen:
- The build is queued - no agents available
- On the docker host you should observe that the tc-docker-build-image is pulled and started
- In TeamCity the agent should register and the build begin
- A couple of minutes later the build should finish
- If you check the registry server (use commands below), you should see the image just built and tagged with build number

If one or more of these steps doesn't happen, probably I forgit to document some step somewhere.  For this I am
sorry because I will probably have forgotten how to repeat all of this.

# Notes
```
#Clean up all exited containers:
docker container rm $(docker container ls -q -f 'status=exited')

#Check registry for images:
curl -k -X GET https://10.10.10.20:5000/v2/_catalog

#Check image in registry for tags:
curl -k -X GET https://10.10.10.20:5000/v2/buildtest/tags/list
```
