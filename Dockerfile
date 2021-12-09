ARG BASEIMAGE=alpine:3.14.2
FROM $BASEIMAGE as base
LABEL maintainer="Denys Zhdanov <denis.zhdanov@gmail.com>"

RUN true \
 && apk add --update --no-cache \
      cairo \
      cairo-dev \
      findutils \
      librrd \
      logrotate \
      memcached \
      nginx \
      nodejs \
      npm \
      redis \
      runit \
      sqlite \
      expect \
      dcron \
      python3-dev \
      mysql-client \
      mysql-dev \
      postgresql-client \
      postgresql-dev \
      librdkafka \
      jansson \
 && rm -rf \
      /etc/nginx/conf.d/default.conf \
 && mkdir -p \
      /var/log/carbon \
      /var/log/graphite \
 && touch /var/log/messages

# optional packages (e.g. not exist on S390 in alpine 3.13 yet)
RUN apk add --update \
      collectd collectd-disk collectd-nginx \
      || true

FROM base as build
LABEL maintainer="Denys Zhdanov <denis.zhdanov@gmail.com>"

ARG python_binary=python3

RUN true \
 && apk add --update \
      alpine-sdk \
      git \
      pkgconfig \
      wget \
      go \
      cairo-dev \
      libffi-dev \
      openldap-dev \
      python3-dev \
      rrdtool-dev \
      jansson-dev \
      librdkafka-dev \
      mysql-dev \
      postgresql-dev \
 && curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
 && $python_binary /tmp/get-pip.py pip==20.1.1 setuptools==50.3.2 wheel==0.35.1 && rm /tmp/get-pip.py \
 && pip install virtualenv==16.7.10 \
 && virtualenv -p $python_binary /opt/graphite \
 && . /opt/graphite/bin/activate \
 && pip install \
      cairocffi==1.1.0 \
      django==2.2.24 \
      django-statsd-mozilla \
      fadvise \
      gunicorn==20.1.0 \
      eventlet>=0.24.1 \
      gevent>=1.4 \
      msgpack==0.6.2 \
      redis \
      rrdtool \
      python-ldap \
      mysqlclient \
      psycopg2 \
      django-cockroachdb==2.2.*

ARG version=1.1.8

# install whisper
ARG whisper_version=${version}
ARG whisper_repo=https://github.com/graphite-project/whisper.git
RUN git clone -b ${whisper_version} --depth 1 ${whisper_repo} /usr/local/src/whisper \
 && cd /usr/local/src/whisper \
 && . /opt/graphite/bin/activate \
 && $python_binary ./setup.py install

# install graphite
ARG graphite_version=${version}
ARG graphite_repo=https://github.com/graphite-project/graphite-web.git
RUN . /opt/graphite/bin/activate \
 && git clone -b ${graphite_version} --depth 1 ${graphite_repo} /usr/local/src/graphite-web \
 && cd /usr/local/src/graphite-web \
 && pip3 install -r requirements.txt \
 && $python_binary ./setup.py install


COPY conf/opt/graphite/conf/                             /opt/defaultconf/graphite/
COPY conf/opt/graphite/webapp/graphite/local_settings.py /opt/defaultconf/graphite/local_settings.py

# config graphite
COPY conf/opt/graphite/conf/* /opt/graphite/conf/
COPY conf/opt/graphite/webapp/graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
WORKDIR /opt/graphite/webapp
RUN mkdir -p /var/log/graphite/ \
  && PYTHONPATH=/opt/graphite/webapp /opt/graphite/bin/django-admin.py collectstatic --noinput --settings=graphite.settings


FROM base as production
LABEL maintainer="Denys Zhdanov <denis.zhdanov@gmail.com>"

COPY conf /

# copy from build image
COPY --from=build /opt /opt

# defaults
EXPOSE 80 2003-2004 2013-2014 2023-2024 8080
VOLUME ["/opt/graphite/conf", "/opt/graphite/storage", "/opt/graphite/webapp/graphite/functions/custom", "/etc/nginx", "/etc/logrotate.d", "/var/log", "/var/lib/redis"]

STOPSIGNAL SIGHUP

ENTRYPOINT ["sh","entrypoint"]
