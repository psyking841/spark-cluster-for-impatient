# base image
# FROM java:openjdk-8-jdk
FROM python:3.7.3-slim

# define spark and hadoop versions
ENV HADOOP_VERSION 2.7.3
ENV SPARK_VERSION 2.4.3

COPY requirement.txt /requirement.txt

RUN set -ex \
    && mkdir -p /usr/share/man/man1 \
    && apt-get update -yqq \
    && apt-get install -yqq --no-install-recommends \
            procps \
            libcurl4-openssl-dev libssl-dev \
            curl \
            openjdk-8-jdk-headless \
            ca-certificates-java \
            gcc g++ \
    && pip install --upgrade pip \
    && pip install -r requirement.txt

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

# download and install hadoop
RUN mkdir -p /opt && \
    cd /opt && \
    curl http://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | \
        tar -zx hadoop-${HADOOP_VERSION}/lib/native && \
    ln -s hadoop-${HADOOP_VERSION} hadoop && \
    echo Hadoop ${HADOOP_VERSION} native libraries installed in /opt/hadoop/lib/native

# download and install spark
RUN mkdir -p /opt && \
    cd /opt && \
    curl http://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop2.7.tgz | \
        tar -zx && \
    ln -s spark-${SPARK_VERSION}-bin-hadoop2.7 spark && \
    echo Spark ${SPARK_VERSION} installed in /opt

ENV SPARK_HOME /opt/spark

# add scripts and update spark default config
ADD common.sh spark-master spark-worker /
ADD spark-defaults.conf /opt/spark/conf/spark-defaults.conf
ENV PATH $PATH:/opt/spark/bin
