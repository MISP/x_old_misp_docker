FROM ubuntu:bionic

ENV DEBIAN_FRONTEND noninteractive

RUN apt update
RUN apt-get install sudo git python3-dev python3-pip libpq5 libjpeg-dev tesseract-ocr libpoppler-cpp-dev imagemagick virtualenv libopencv-dev zbar-tools libzbar0 libzbar-dev libfuzzy-dev build-essential -y
RUN apt-get install -y

RUN adduser www-data sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
WORKDIR /usr/local/src/
RUN chown -R www-data .
USER www-data
RUN sudo git clone https://github.com/MISP/misp-modules.git

WORKDIR ./misp-modules
RUN sudo chown -R www-data .

RUN sudo pip3 install --upgrade pip
RUN sed -i 's/aiohttp==3.4.4/aiohttp/g' REQUIREMENTS
RUN sudo pip3 install --upgrade --ignore-installed urllib3
RUN sudo pip3 install --upgrade --ignore-installed requests

RUN sed -i 's/aiohttp.*/aiohttp/g' REQUIREMENTS
RUN sed -i 's/functools.*//g' REQUIREMENTS
RUN sed -i 's/async-timeout.*/async-timeout/g' REQUIREMENTS
RUN sed -i 's/url-normalize.*/url-normalize/g' REQUIREMENTS
RUN sed -i 's/^\(yarl\)\=.*/\1/g' REQUIREMENTS
RUN sed -i 's/^\(sigmatools\)\=.*/\1/' REQUIREMENTS
RUN sed -i 's/^\(socketio-client\)\=.*/\1/' REQUIREMENTS

RUN sudo pip3 install -I -r REQUIREMENTS
RUN sudo pip3 install .
# Start misp-modules as a service
#RUN sudo cp etc/systemd/system/misp-modules.service /etc/systemd/system/
#RUN sudo systemctl daemon-reload
#RUN sudo systemctl enable --now misp-modules

CMD misp-modules -l 0.0.0.0
