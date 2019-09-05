#
# Dockerfile to build a MISP (https://github.com/MISP/MISP) container
#
# Original docker file by eg5846 (https://github.com/eg5846)
#
# 2016/03/03 - First release
# 2017/06/02 - Updated
# 2018/04/04 - Added objects templates
# 

# We are based on Ubuntu:latest
FROM ubuntu:xenial
MAINTAINER Xavier Mertens <xavier@rootshell.be>

ENV LANG en_US.UTF-8
ENV DEBIAN_FRONTEND noninteractive

# Update packages and install additional components
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales software-properties-common \
    && locale-gen en_US.UTF-8

RUN add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get autoremove -y \
    && apt-get clean

# Preconfigure setting for packages
RUN echo "postfix postfix/main_mailer_type string Local only" | debconf-set-selections
RUN echo "postfix postfix/mailname string localhost.localdomain" | debconf-set-selections

RUN apt-get install -y \
        # Core components \
        postfix mysql-client curl gcc git gnupg-agent make python openssl redis-server sudo vim zip software-properties-common \
        # Apache \
        apache2 apache2-doc apache2-utils \
        # Python \
        python-dev python-pip libxml2-dev libxslt1-dev zlib1g-dev python-setuptools libfuzzy-dev \
        python3 python3-pip libjpeg-dev python-lxml python3-lxml \
        # Misc tools \
        cron logrotate supervisor syslog-ng-core \
        # MISP build requirements \
        libpoppler58 libpoppler-dev libpoppler-cpp-dev \
        # PHP 7.2 \
        libapache2-mod-php php7.2 php7.2-cli php-crypt-gpg \
        php7.2-dev php7.2-json php7.2-mysql php7.2-opcache php7.2-readline php7.2-redis php7.2-xml \
        php-pear pkg-config libbson-1.0 libmongoc-1.0-0 php-xml php-dev php-gd \
        # install MySQL PDO extension \
        php-mysql \
    && apt-get clean \
    # Fix php.ini with recommended settings \
    && sed -i \
        -e "s/max_execution_time = 30/max_execution_time = 300/" \
        -e "s/memory_limit = 128M/memory_limit = 2048M/" \
        -e "s/upload_max_filesize = 2M/upload_max_filesize = 50M/" \
        -e "s/post_max_size = 8M/post_max_size = 50M/" \
        /etc/php/7.2/apache2/php.ini

# update setuptools because otherwise you'' get python errors
RUN pip install --upgrade setuptools

RUN chown www-data:www-data /var/www
USER www-data

# Download the main repository
RUN cd /var/www && git clone https://github.com/MISP/MISP.git
RUN cd /var/www/MISP \
    && git checkout tags/$(git describe --tags `git rev-list --tags --max-count=1`) \
	&& git config core.filemode false \
    && git submodule update --init --recursive \
	# Make git ignore filesystem permission differences for submodules \
	&& git submodule foreach --recursive git config core.filemode false

RUN cd /var/www/MISP/app/files/scripts \
	&& git clone -b v2.1.0.12 https://github.com/CybOXProject/python-cybox.git \
    && git clone -b v1.1.1.4 https://github.com/STIXProject/python-stix.git

USER root
RUN cd /var/www/MISP/app/files/scripts/python-cybox \
	&& python setup.py install \
    && cd /var/www/MISP/app/files/scripts/python-stix \
	&& python setup.py install

USER www-data
WORKDIR /var/www/MISP
RUN git submodule init \
    && git submodule update
WORKDIR /var/www/MISP/app

# FIX COMPOSER
RUN curl --fail --location -o composer-setup.php https://getcomposer.org/installer \
    && php -r "if (hash_file('sha384', 'composer-setup.php') === 'a5c698ffe4b8e849a443b120cd5ba38043260d5c4023dbf93e1558871f1f07f58274fc6f4c93bcfd858c6bd0775cd8d1') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');"
# END FIX

RUN php composer.phar update \
    && php composer.phar config vendor-dir Vendor \
    && php composer.phar install --ignore-platform-reqs
USER root
RUN phpenmod redis

# MISP base configuration
RUN cp -a /var/www/MISP/INSTALL/setup/config.php /var/www/MISP/app/Plugin/CakeResque/Config/config.php \
    && cd /var/www/MISP/app/Config \
    && cp -a bootstrap.default.php bootstrap.php \
    && cp -a database.default.php database.php \
    && cp -a core.default.php core.php \
    && cp -a config.default.php config.php

# Replace the default salt
RUN sed -i -E "s/'salt'\s=>\s'(\S+)'/'salt' => '`openssl rand -base64 32|tr "/" "-"`'/" /var/www/MISP/app/Config/config.php

# Fix permissions
RUN chown -R www-data:www-data /var/www/MISP \
    && chmod -R 750 /var/www/MISP \
    && chmod -R g+ws /var/www/MISP/app/tmp \
    && chmod -R g+ws /var/www/MISP/app/files \
    && chmod -R g+ws /var/www/MISP/app/files/scripts/tmp \
    && chmod +x /var/www/MISP/app/Console/cake

# Apache Setup
RUN cp /var/www/MISP/INSTALL/apache.misp.ubuntu /etc/apache2/sites-available/misp.conf \
    && a2dismod status \
    && a2dissite 000-default \
    && a2ensite misp \
    && a2enmod rewrite \
    && a2enmod headers \
    # Redis Setup \
    && sed -i 's/^\(daemonize\s*\)yes\s*$/\1no/g' /etc/redis/redis.conf \
    # Logrotate Setup \
    && cp /var/www/MISP/INSTALL/misp.logrotate /etc/logrotate.d/misp

# Enable workers at boot time
RUN chmod a+x /var/www/MISP/app/Console/worker/start.sh \
    && echo "sudo -u www-data bash /var/www/MISP/app/Console/worker/start.sh" >>/etc/rc.local

# Install templates & stuff
RUN cd /var/www/MISP/app/files \
    && rm -rf misp-objects && git clone https://github.com/MISP/misp-objects.git \
    && rm -rf misp-galaxy && git clone https://github.com/MISP/misp-galaxy.git \
    && rm -rf warninglists && git clone https://github.com/MISP/misp-warninglists.git ./warninglists \
    && rm -rf taxonomies && git clone https://github.com/MISP/misp-taxonomies.git ./taxonomies \
    && chown -R www-data:www-data misp-objects misp-galaxy warninglists taxonomies

# Install MISP Modules
WORKDIR /opt
# PIP3 fix
RUN pip install --upgrade pip
# END FIX
RUN git clone https://github.com/MISP/misp-modules.git
WORKDIR /opt/misp-modules
RUN pip3 install --upgrade pip
RUN sed -i \
        -e 's/aiohttp.*/aiohttp/g' \
        -e 's/functools.*//g' \
        -e 's/async-timeout.*/async-timeout/g' \
        -e 's/url-normalize.*/url-normalize/g' \
        -e 's/^\(yarl\)\=.*/\1/g' \
        -e 's/^\(sigmatools\)\=.*/\1/' \
        REQUIREMENTS
RUN pip3 install --upgrade --ignore-installed urllib3
RUN pip3 install --upgrade --ignore-installed requests 
RUN pip3 install -I -r REQUIREMENTS
RUN pip3 install -I .
RUN echo "sudo -u www-data misp-modules -s -l 127.0.0.1 &" >>/etc/rc.local

# Supervisord Setup
RUN cd /etc/supervisor/conf.d \
    && echo '[supervisord]' >> supervisord.conf \
    && echo 'nodaemon = true' >> supervisord.conf \
    && echo >> supervisord.conf \
    && echo '[program:postfix]' >> supervisord.conf \
    && echo 'process_name = master' >> supervisord.conf \
    && echo 'directory = /etc/postfix' >> supervisord.conf \
    && echo 'command = /usr/sbin/postfix -c /etc/postfix start' >> supervisord.conf \
    && echo 'startsecs = 0' >> supervisord.conf \
    && echo 'autorestart = false' >> supervisord.conf \
    && echo >> supervisord.conf \
    && echo '[program:redis-server]' >> supervisord.conf \
    && echo 'command=redis-server /etc/redis/redis.conf' >> supervisord.conf \
    && echo >> supervisord.conf \
    && echo '[program:apache2]' >> supervisord.conf \
    && echo 'command=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -D FOREGROUND"' >> supervisord.conf \
    && echo >> supervisord.conf \
    && echo '[program:resque]' >> supervisord.conf \
    && echo 'command=/bin/bash /var/www/MISP/app/Console/worker/start.sh' >> supervisord.conf \
    && echo 'user = www-data' >> supervisord.conf \
    && echo 'startsecs = 0' >> supervisord.conf \
    && echo 'autorestart = false' >> supervisord.conf \
    && echo >> supervisord.conf \
    && echo '[program:misp-modules]' >> supervisord.conf \
    && echo 'command=/bin/bash -c "misp-modules -s -l 127.0.0.1"' >> supervisord.conf \
    && echo 'user = www-data' >> supervisord.conf \
    && echo 'startsecs = 0' >> supervisord.conf \
    && echo 'autorestart = false' >> supervisord.conf
# Modify syslog configuration
RUN sed -i -E 's/^(\s*)system\(\);/\1unix-stream("\/dev\/log");/' /etc/syslog-ng/syslog-ng.conf

# Add run script
ADD run.sh /run.sh
RUN chmod 0755 /run.sh

# Trigger to perform first boot operations
RUN touch /.firstboot.tmp

# Make a backup of /var/www/MISP to restore it to the local moint point at first boot
WORKDIR /var/www/MISP
RUN tar czpf /root/MISP.tgz .

VOLUME /var/www/MISP
EXPOSE 80
ENTRYPOINT ["/run.sh"]
