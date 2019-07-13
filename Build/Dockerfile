FROM thingsboard/tb:latest

MAINTAINER Manfredi Pistone <manfredi.pistone@gmail.com>

USER root

COPY ./start-tb.sh /usr/bin/start-tb.sh
RUN chmod 775 /usr/bin/start-tb.sh

COPY ./install-dashboards.sh /usr/bin/install-dashboards.sh
RUN chmod 775 /usr/bin/install-dashboards.sh
