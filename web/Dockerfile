
FROM ubuntu:focal
# Install core components
ENV DEBIAN_FRONTEND noninteractive

# This will install MISP Core
RUN wget -O /tmp/INSTALL.sh https://raw.githubusercontent.com/MISP/MISP/2.4/INSTALL/INSTALL.sh
RUN bash /tmp/INSTALL.sh -c

VOLUME /var/www/MISP
EXPOSE 80 2222

ENTRYPOINT ["/run.sh"]
