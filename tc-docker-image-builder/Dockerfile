## This part is taken from the Dockerfile building "jetbrains/teamcity-minimal-agent
## https://github.com/JetBrains/teamcity-docker-minimal-agent
##
## Building:
##   docker build --build-arg registry_host=<host> . 
###################################
FROM adoptopenjdk/openjdk8:x86_64-ubuntu-jdk8u192-b12

ARG registry_host
RUN test -n "$registry_host" || (echo "registry_host not set to the hostname of the registry server\nSet using --build-arg registry_host=..." && false)

VOLUME /data/teamcity_agent/conf

ENV CONFIG_FILE=/data/teamcity_agent/conf/buildAgent.properties \
    LANG=C.UTF-8

LABEL dockerImage.teamcity.version="latest" \
      dockerImage.teamcity.buildNumber="latest"


COPY run-agent.sh /run-agent.sh
COPY run-services.sh /run-services.sh
COPY dist/buildagent /opt/buildagent

RUN apt-get update && \
    apt-get install -y --no-install-recommends sudo && \
    useradd -m buildagent && \
    chmod +x /opt/buildagent/bin/*.sh && \
    chmod +x /run-agent.sh /run-services.sh && sync

## This part installs docker:
##################################
# IF you want to use the convenience script: (remember to install git and systemd separately then)
#RUN curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh

RUN apt-get update -qq && \
    apt-get install -y git systemd software-properties-common

RUN apt-get install -y -qq apt-transport-https ca-certificates curl gnupg && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
    apt-cache policy docker-ce && \
    apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends docker-ce


RUN systemctl disable docker
RUN rm -rf /var/lib/apt/lists/* && \
    apt-get clean all && \
    usermod -aG docker buildagent

VOLUME /var/lib/docker

COPY run-docker.sh /services/run-docker.sh

# Need to set certificate for registry host to enable pushing to it from this container
COPY ca.crt /etc/docker/certs.d/$registry_host/ca.crt

CMD ["/run-services.sh"]
EXPOSE 9090
