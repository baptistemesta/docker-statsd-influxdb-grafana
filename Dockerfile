FROM ubuntu:16.04
MAINTAINER Samuele Bistoletti <samuele.bistoletti@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8

# Default versions
ENV INFLUXDB_VERSION 1.5.2
ENV GRAFANA_VERSION  5.1.2

# Database Defaults
ENV INFLUXDB_GRAFANA_DB datasource
ENV INFLUXDB_GRAFANA_USER datasource
ENV INFLUXDB_GRAFANA_PW datasource

ENV MYSQL_GRAFANA_USER grafana
ENV MYSQL_GRAFANA_PW grafana

# Fix bad proxy issue
COPY system/99fixbadproxy /etc/apt/apt.conf.d/99fixbadproxy

# Clear previous sources
RUN rm /var/lib/apt/lists/* -vf

# Base dependencies
RUN apt-get -y update && \
 apt-get -y dist-upgrade && \
 apt-get -y --force-yes install \
  apt-utils \
  ca-certificates \
  curl \
  git \
  htop \
  libfontconfig \
  mysql-client \
  mysql-server \
  nano \
  net-tools \
  openssh-server \
  supervisor \
  openjdk-8-jdk \
  wget && \
 curl -sL https://deb.nodesource.com/setup_7.x | bash - && \
 apt-get install -y nodejs

WORKDIR /root

RUN mkdir -p /var/log/supervisor && \
    mkdir -p /var/run/sshd && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo 'root:root' | chpasswd && \
    rm -rf .ssh && \
    rm -rf .profile && \
    mkdir .ssh

COPY bash/profile .profile

# Configure MySql
COPY scripts/setup_mysql.sh /tmp/setup_mysql.sh

RUN /tmp/setup_mysql.sh

# Install InfluxDB
RUN wget https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_amd64.deb && \
	dpkg -i influxdb_${INFLUXDB_VERSION}_amd64.deb && rm influxdb_${INFLUXDB_VERSION}_amd64.deb

# Configure InfluxDB
COPY influxdb/influxdb.conf /etc/influxdb/influxdb.conf
COPY influxdb/init.sh /etc/init.d/influxdb


# Install Grafana
RUN wget https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana_${GRAFANA_VERSION}_amd64.deb && \
	dpkg -i grafana_${GRAFANA_VERSION}_amd64.deb && rm grafana_${GRAFANA_VERSION}_amd64.deb
# Configure Grafana
COPY grafana/grafana.ini /etc/grafana/grafana.ini
COPY grafana/dashboard.yaml /etc/grafana/provisioning/dashboards/dashboard.yaml
COPY grafana/datasource.yaml /etc/grafana/provisioning/datasources/datasource.yaml
COPY grafana/bonita-dashboard.json /var/lib/grafana/dashboards/bonita-dashboard.json

# Add jmx trans
RUN mkdir -p /var/lib/jmxtrans/lib
RUN wget http://central.maven.org/maven2/org/jmxtrans/jmxtrans/270/jmxtrans-270-all.jar -O /var/lib/jmxtrans/lib/jmxtrans-all.jar
RUN wget -q https://raw.githubusercontent.com/jmxtrans/jmxtrans/master/jmxtrans/jmxtrans.sh -O /var/lib/jmxtrans/jmxtrans.sh
RUN chmod +x /var/lib/jmxtrans/jmxtrans.sh
COPY jmxtrans/bonita-jmx.json /var/lib/jmxtrans/.


# Configure Supervisord, SSH and base env
COPY supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Cleanup
RUN apt-get clean && \
 rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

CMD ["/usr/bin/supervisord"]
