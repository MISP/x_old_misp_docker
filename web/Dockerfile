
FROM ubuntu:bionic

# Install core components
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get dist-upgrade -y && apt-get autoremove -y && apt-get clean && \
    apt-get install -y software-properties-common && \
    apt-get install -y postfix && \
    apt-get install -y mysql-client curl gcc git gnupg-agent \
        make python openssl redis-server sudo vim zip locales

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
RUN add-apt-repository -y ppa:ondrej/php && apt-get update

# Apache
RUN apt-get install -y apache2 apache2-doc apache2-utils && \
    a2dismod status && \
    a2dissite 000-default

# PHP 7.2 and install MySQL PDO extension
RUN apt-get install -y libapache2-mod-php7.2 php7.2 php7.2-cli php7.2-dev \
        php7.2-json php7.2-mysql php7.2-opcache php7.2-readline php7.2-redis \
	php7.2-xml && \
    apt-get install -y php-pear pkg-config libbson-1.0 libmongoc-1.0-0 \
        php7.2-xml php7.2-dev php7.2-gd && \
    apt-get install -y php7.2-mysql && \
    apt-get install -y php7.2-mbstring

# Fix php.ini with recommended settings
RUN sed -i "s/max_execution_time = 30/max_execution_time = 300/" \
        /etc/php/7.2/apache2/php.ini && \
    sed -i "s/memory_limit = 128M/memory_limit = 2048M/" \
        /etc/php/7.2/apache2/php.ini && \
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 50M/" \
        /etc/php/7.2/apache2/php.ini && \
    sed -i "s/post_max_size = 8M/post_max_size = 50M/" \
        /etc/php/7.2/apache2/php.ini

RUN apt-get install -y python-dev python-pip libxml2-dev libxslt1-dev \
        zlib1g-dev python-setuptools libfuzzy-dev python-lxml python3-lxml && \
    apt-get install -y cron logrotate supervisor syslog-ng-core && \
    apt-get clean

# update setuptools because otherwise you'' get python errors
RUN pip install --upgrade setuptools

WORKDIR /var/www
RUN chown www-data:www-data /var/www
USER www-data
RUN git clone https://github.com/MISP/MISP.git
WORKDIR /var/www/MISP
RUN git checkout tags/$(git describe --tags `git rev-list --tags --max-count=1`) && \
    git config core.filemode false && \
    git submodule update --init --recursive && \
    git submodule foreach --recursive git config core.filemode false

WORKDIR /var/www/MISP/app/files/scripts
RUN git clone https://github.com/CybOXProject/python-cybox.git && \
    git clone https://github.com/STIXProject/python-stix.git

WORKDIR /var/www/MISP/app/files/scripts/python-cybox
RUN git checkout v2.1.0.12
USER root
RUN python setup.py install

USER www-data
WORKDIR /var/www/MISP/app/files/scripts/python-stix
RUN git checkout v1.1.1.4
USER root
RUN python setup.py install

USER www-data
WORKDIR /var/www/MISP
RUN git submodule init && git submodule update
WORKDIR /var/www/MISP/app

# FIX COMPOSER
RUN curl --fail --location -o composer-setup.php https://getcomposer.org/installer && \
    EXPECTED_SIGNATURE="$(curl https://composer.github.io/installer.sig)"; php -r "if (hash_file('sha384', 'composer-setup.php') == '$(echo $EXPECTED_SIGNATURE)' ) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');"
# END FIX

RUN php composer.phar update && \
    php composer.phar config vendor-dir Vendor && \
    php composer.phar install --ignore-platform-reqs
USER root
RUN phpenmod redis
USER www-data
RUN cp -fa /var/www/MISP/INSTALL/setup/config.php /var/www/MISP/app/Plugin/CakeResque/Config/config.php

# Fix permissions
USER root
RUN chown -R www-data:www-data /var/www/MISP && \
    chmod -R 750 /var/www/MISP && \
    chmod -R g+ws /var/www/MISP/app/tmp && \
    chmod -R g+ws /var/www/MISP/app/files && \
    chmod -R g+ws /var/www/MISP/app/files/scripts/tmp && \
    chmod +x /var/www/MISP/app/Console/cake

RUN cp /var/www/MISP/INSTALL/misp.logrotate /etc/logrotate.d/misp

# Preconfigure setting for packages
RUN echo "postfix postfix/main_mailer_type string Local only" \
  | debconf-set-selections && \
    echo "postfix postfix/mailname string localhost.localdomain" | \
    debconf-set-selections

# Redis Setup
RUN sed -i 's/^\(daemonize\s*\)yes\s*$/\1no/g' /etc/redis/redis.conf
RUN sed -i 's/^\(bind\s*\)127.0.0.1 ::1\s*$/\1127.0.0.1/g' /etc/redis/redis.conf

# Apache Setup
RUN cp /var/www/MISP/INSTALL/apache.misp.ubuntu /etc/apache2/sites-available/misp.conf && \
    a2dissite 000-default && \
    a2ensite misp && \
    a2enmod rewrite && \
    a2enmod headers

# MISP base configuration
RUN sudo -u www-data cp -a /var/www/MISP/app/Config/bootstrap.default.php /var/www/MISP/app/Config/bootstrap.php && \
    sudo -u www-data cp -a /var/www/MISP/app/Config/database.default.php /var/www/MISP/app/Config/database.php && \
    sudo -u www-data cp -a /var/www/MISP/app/Config/core.default.php /var/www/MISP/app/Config/core.php && \
    sudo -u www-data cp -a /var/www/MISP/app/Config/config.default.php /var/www/MISP/app/Config/config.php && \
    chown -R www-data:www-data /var/www/MISP/app/Config && \
    chmod -R 750 /var/www/MISP/app/Config

# Replace the default salt
RUN sed -i -E "s/'salt'\s=>\s'(\S+)'/'salt' => '`openssl rand -base64 32|tr "/" "-"`'/" /var/www/MISP/app/Config/config.php

# Enable workers at boot time
RUN chmod a+x /var/www/MISP/app/Console/worker/start.sh && \
    echo "sudo -u www-data bash /var/www/MISP/app/Console/worker/start.sh" >>/etc/rc.local

# Install templates & stuff
WORKDIR /var/www/MISP/app/files
RUN rm -rf misp-objects && git clone https://github.com/MISP/misp-objects.git && \
    rm -rf misp-galaxy && git clone https://github.com/MISP/misp-galaxy.git && \
    rm -rf warninglists && git clone https://github.com/MISP/misp-warninglists.git ./warninglists && \
    rm -rf taxonomies && git clone https://github.com/MISP/misp-taxonomies.git ./taxonomies && \
    chown -R www-data:www-data misp-objects misp-galaxy warninglists taxonomies

# Install MISP build requirements
RUN sudo -E apt-get -y install libpoppler73 libpoppler-dev libpoppler-cpp-dev

# Install MISP Modules
WORKDIR /opt
RUN apt-get install -y python3 python3-pip libjpeg-dev
# PIP3 fix
RUN pip3 install --upgrade pip
# END FIX
RUN git clone https://github.com/MISP/misp-modules.git
WORKDIR /opt/misp-modules
RUN pip3 install --upgrade pip && \
    cat REQUIREMENTS | sed 's/aiohttp==3.4.4/aiohttp/g' > REQUIREMENTS && \
    pip3 install --upgrade --ignore-installed urllib3 && \
    pip3 install --upgrade --ignore-installed requests

RUN sed -i 's/aiohttp.*/aiohttp/g' REQUIREMENTS && \
    sed -i 's/functools.*//g' REQUIREMENTS && \
    sed -i 's/async-timeout.*/async-timeout/g' REQUIREMENTS && \
    sed -i 's/url-normalize.*/url-normalize/g' REQUIREMENTS && \
    sed -i 's/^\(yarl\)\=.*/\1/g' REQUIREMENTS && \
    sed -i 's/^\(sigmatools\)\=.*/\1/' REQUIREMENTS && \
    pip3 install -I -r REQUIREMENTS && \
    pip3 install -I . && \
    echo "sudo -u www-data misp-modules -s -l 127.0.0.1 &" >>/etc/rc.local

# Supervisord Setup
RUN ( \
    echo '[supervisord]'; \
    echo 'nodaemon = true'; \
    echo ''; \
    echo '[program:postfix]'; \
    echo 'process_name = master'; \
    echo 'directory = /etc/postfix'; \
    echo 'command = /usr/sbin/postfix -c /etc/postfix start'; \
    echo 'startsecs = 0'; \
    echo 'autorestart = false'; \
    echo ''; \
    echo '[program:redis-server]'; \
    echo 'command=redis-server /etc/redis/redis.conf'; \
    echo ''; \
    echo '[program:apache2]'; \
    echo 'command=/bin/bash -c "source /etc/apache2/envvars && exec /usr/sbin/apache2 -D FOREGROUND"'; \
    echo ''; \
    echo '[program:resque]'; \
    echo 'command=/bin/bash /var/www/MISP/app/Console/worker/start.sh'; \
    echo 'user = www-data'; \
    echo 'startsecs = 0'; \
    echo 'autorestart = false'; \
    echo ''; \
    echo '[program:misp-modules]'; \
    echo 'command=/bin/bash -c "misp-modules -s -l 127.0.0.1"'; \
    echo 'user = www-data'; \
    echo 'startsecs = 0'; \
    echo 'autorestart = false'; \
) >> /etc/supervisor/conf.d/supervisord.conf
 
# Modify syslog configuration
RUN sed -i -E 's/^(\s*)system\(\);/\1unix-stream("\/dev\/log");/' /etc/syslog-ng/syslog-ng.conf

# Add run script
# Trigger to perform first boot operations
ADD run.sh /run.sh
RUN chmod 0755 /run.sh && touch /.firstboot.tmp


# Make a backup of /var/www/MISP to restore it to the local moint point at first boot
WORKDIR /var/www/MISP
RUN tar czpf /root/MISP.tgz .

VOLUME /var/www/MISP
EXPOSE 80
ENTRYPOINT ["/run.sh"]
