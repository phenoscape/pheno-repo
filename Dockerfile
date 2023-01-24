FROM ubuntu:22.04

LABEL maintainer="balhoff@renci.org"

WORKDIR /tools

RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get install -y locales &&\
        rm -rf /var/lib/apt/lists/* && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get install -y \
    wget \
    openjdk-17-jdk \
    openjdk-17-jre

###### ROBOT #####
ENV ROBOT_VERSION=1.9.1
RUN wget -nv https://github.com/ontodev/robot/releases/download/v$ROBOT_VERSION/robot.jar \
        -O /tools/robot.jar && \
    wget -nv https://raw.githubusercontent.com/ontodev/robot/v$ROBOT_VERSION/bin/robot \
        -O /tools/robot && \
    chmod 755 /tools/robot

###### blazegraph-runner #####
ENV BR_VERSION=1.7
ENV PATH "/tools/blazegraph-runner/bin:$PATH"
RUN wget -nv https://github.com/balhoff/blazegraph-runner/releases/download/v$BR_VERSION/blazegraph-runner-$BR_VERSION.tgz \
&& tar -zxvf blazegraph-runner-$BR_VERSION.tgz \
&& mv blazegraph-runner-$BR_VERSION /tools/blazegraph-runner

###### relation-graph #####
ENV RG_VERSION=2.3.1
ENV PATH "/tools/relation-graph/bin:$PATH"
RUN wget -nv https://github.com/balhoff/relation-graph/releases/download/v$RG_VERSION/relation-graph-cli-$RG_VERSION.tgz \
&& tar -zxvf relation-graph-cli-$RG_VERSION.tgz \
&& mv relation-graph-cli-$RG_VERSION /tools/relation-graph

###### jena #####
ENV JENA_VERSION=4.7.0
ENV PATH "/tools/apache-jena/bin:$PATH"
RUN wget -nv http://archive.apache.org/dist/jena/binaries/apache-jena-$JENA_VERSION.tar.gz -O- | tar xzC /tools && \
    mv /tools/apache-jena-$JENA_VERSION /tools/apache-jena
