FROM centos:centos7

RUN yum install -y --setopt=tsflags=nodocs yum-utils wget which lsof epel-release \
	unzip tar bsdtar procps-ng gettext which gcc-c++ automake autoconf \
	curl-devel openssl-devel zlib-devel libxslt-devel libxml2-devel gdb \
	mysql-libs mysql-devel postgresql-devel sqlite-devel && \
    yum clean all -y

RUN rpm -i https://www.softwarecollections.org/en/scls/rhscl/v8314/epel-7-x86_64/download/rhscl-v8314-epel-7-x86_64.noarch.rpm && \
    rpm -i https://www.softwarecollections.org/en/scls/rhscl/nodejs010/epel-7-x86_64/download/rhscl-nodejs010-epel-7-x86_64.noarch.rpm && \
    yum install -y --setopt=tsflags=nodocs nodejs010 && \
    yum clean all -y


ADD ./nodejs         /opt/nodejs/
ADD ./.sti/bin/usage /opt/nodejs/bin/


ENV STI_SCRIPTS_URL https://raw.githubusercontent.com/openshift/sti-nodejs/master/.sti/bin


ENV STI_LOCATION /tmp


RUN mkdir -p /opt/nodejs/{run,src} && \
    groupadd -r nodejs -f -g 433 && \
    useradd -u 431 -r -g nodejs -d /opt/nodejs -s /sbin/nologin -c "NodeJS user" nodejs && \
    chown -R nodejs:nodejs /opt/nodejs


ENV APP_ROOT .
ENV HOME     /opt/nodejs
ENV PATH     $HOME/bin:$PATH

ENV STI_NODEJS_VERSION 0.10

WORKDIR     /opt/nodejs/src

USER nodejs


EXPOSE 3000

CMD ["/opt/nodejs/bin/usage"]