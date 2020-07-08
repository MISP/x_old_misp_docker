
FROM ubuntu:focal
# Install core components
ENV DEBIAN_FRONTEND noninteractive
RUN apt update -y && apt install wget sudo -y
# This will install MISP Core
RUN wget -O /tmp/INSTALL.sh https://raw.githubusercontent.com/MISP/MISP/2.4/INSTALL/INSTALL.sh
RUN sed -i 's/> \/dev\/tty//' /tmp/INSTALL.sh
RUN sed -i 's/> \/dev\/null//' /tmp/INSTALL.sh 
RUN sed -i 's/checkInstaller$/#checkInstaller/' /tmp/INSTALL.sh
RUN bash /tmp/INSTALL.sh -c

VOLUME /var/www/MISP
EXPOSE 80 2222

ENTRYPOINT ["/run.sh"]
