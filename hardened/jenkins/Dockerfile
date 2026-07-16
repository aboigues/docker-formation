FROM jenkins/jenkins:lts-jdk21
USER root
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
USER jenkins
