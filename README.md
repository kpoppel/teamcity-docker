# teamcity-docker
I wanted to try to setup TeamCity in a container, then run agents is Docker containers, and have those containers build me docker images.

Step 1: TeamCity
  Get Linux on a host machine
  Install docker (curl https://get.docker.-com -output get_docker.sh && sh get_docker.sh)
  Pull teamcity docker image
  > docker pull jetbrains/teamcity:latest
 
 Setup Teamcity acount and so on.
 
Step 2: Setup a docker registry.
  Pull the registry.  Use he compose file: docker-registry/docker-compose-yml
  Generate
  Works with IP addresses (and DNS you don't need the openssl.cnf change):
# Edit the file /etc/ssl/openssl.cnf on the registry:2 host and add
#  [ v3_ca ]
#    subjectAltName = IP:10.0.0.112
#
# or:
#    subjectAltName = DNS:registry.mydomain.lan,IP:10.0.0.112,IP:127.0.0.1

openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout certs/domain.key \
  -x509 -days 365 -out certs/domain.crt \

# Clean up /etc/ssl/openssl.cnf file again.

# Be sure to use the host name like "registry.home.lan" as a CN.
# Linux: Copy the domain.crt file to /etc/docker/certs.d/myregistrydomain.com:5000/ca.crt on every Docker host.
# You do not need to restart Docker.
sudo mkdir -p /etc/docker/certs.d/10.0.0.112:5000
sudo scp kpo@10.0.0.112:/home/kpo/development/teamcity-docker/dockerfiles/docker-registry/certs/domain.crt /etc/docker/certs.d/10.0.0.112:5000/ca.crt
