FROM centos:centos6

MAINTAINER Hiroaki Sano <hiroaki.sano.9stories@gmail.com>

# Basic packages
RUN rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm \
  && yum -y install passwd sudo git wget openssl openssh openssh-server openssh-clients 
RUN yum -y install gcc gcc-c++ sysstat postgresql-libs postgresql-devel

# Create user
RUN useradd hiroakis \
 && echo "hiroakis" | passwd hiroakis --stdin \
 && sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config \
 && sed -ri 's/#UsePAM no/UsePAM no/g' /etc/ssh/sshd_config \
 && echo "hiroakis ALL=(ALL) ALL" >> /etc/sudoers.d/hiroakis

# Redis
RUN yum install -y redis

# RabbitMQ
RUN rpm -Uvh https://www.rabbitmq.com/releases/erlang/erlang-18.2-1.el6.x86_64.rpm \
  && rpm --import http://www.rabbitmq.com/rabbitmq-signing-key-public.asc \
  && rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.1.4/rabbitmq-server-3.1.4-1.noarch.rpm \
  && git clone git://github.com/joemiller/joemiller.me-intro-to-sensu.git \
  && cd joemiller.me-intro-to-sensu/; ./ssl_certs.sh clean && ./ssl_certs.sh generate \
  && mkdir /etc/rabbitmq/ssl \
  && cp /joemiller.me-intro-to-sensu/server_cert.pem /etc/rabbitmq/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/server_key.pem /etc/rabbitmq/ssl/key.pem \
  && cp /joemiller.me-intro-to-sensu/testca/cacert.pem /etc/rabbitmq/ssl/
ADD ./files/rabbitmq.config /etc/rabbitmq/
RUN rabbitmq-plugins enable rabbitmq_management

# Sensu server
ADD ./files/sensu.repo /etc/yum.repos.d/
RUN yum install -y sensu
ADD ./files/config.json /etc/sensu/
RUN mkdir -p /etc/sensu/ssl \
  && cp /joemiller.me-intro-to-sensu/client_cert.pem /etc/sensu/ssl/cert.pem \
  && cp /joemiller.me-intro-to-sensu/client_key.pem /etc/sensu/ssl/key.pem

# uchiwa
RUN yum install -y uchiwa
ADD ./files/uchiwa.json /etc/sensu/

# supervisord
RUN wget http://peak.telecommunity.com/dist/ez_setup.py;python ez_setup.py \
  && easy_install supervisor
ADD files/supervisord.conf /etc/supervisord.conf

RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install vmstat"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install pg"

RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-http"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-cpu-checks"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-memory-checks"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-postgres"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-network-checks"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-mailer aws-ses"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-graphite"
RUN /bin/bash -l -c "/opt/sensu/embedded/bin/gem install sensu-plugins-vmstats"

ADD files/check-*.json /etc/sensu/conf.d/
ADD files/client-*.json /etc/sensu/conf.d/
ADD files/mailer-*.json /etc/sensu/conf.d/
ADD files/handler-*.json /etc/sensu/conf.d/
ADD files/mutator-*.json /etc/sensu/conf.d/
ADD files/filter-*.json /etc/sensu/conf.d/

EXPOSE 3000

CMD ["/usr/bin/supervisord"]

