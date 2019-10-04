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
  
  Create a project and add a cloud config to it.
  
  
## Step 2: Agents on docker host
  Next we want to run an agent in a cloud
 
# Step 3: Setup a docker registry.
  Pull the registry.  Use he compose file: docker-registry/docker-compose-yml
  Generate TLS keys.  I just wanted to use IP addresses to access the registry, which meant some more work.
  If you have a DNS already setup, go for method 2.
  
##  Method 1 (if you want to use IP addresses):
  Edit the file /etc/ssl/openssl.cnf on the registry:2 host and add
  ```
    [ v3_ca ]
        subjectAltName = IP:10.10.10.20
  ```
  or:
  ```
        subjectAltName = DNS:registry.mydomain.lan,IP:10.10.10.20,IP:127.0.0.1
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
  sudo mkdir -p /etc/docker/certs.d/10.0.0.112:5000
  sudo scp kpo@10.0.0.112:/home/kpo/development/teamcity-docker/dockerfiles/docker-registry/certs/domain.crt /etc/docker/certs.d/10.0.0.112:5000/ca.crt
```
  
## Test the registry works
```bash
 docker pull ubuntu:16.04
 docker tag ubuntu:16.04 myregistrydomain.com/my-ubuntu
 docker push myregistrydomain.com/my-ubuntu
 docker pull myregistrydomain.com/my-ubuntu
```
