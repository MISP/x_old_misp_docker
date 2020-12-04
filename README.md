MISP Docker
===========

[![](https://travis-ci.org/MISP/misp-docker.svg?branch=master)](https://travis-ci.org/yaleman/misp-docker)

The files in this repository are used to create a Docker container running a [MISP](http://www.misp-project.org) ("Malware Information Sharing Platform") instance.

I rewrote the Docker file to split the components in multiple containers (which is more in the philosophy of Docker). Therefore there is no longer a Dockerfile in the root directory.

The MISP container needs at least a MySQL container to store the data. By default it listen to port 80. I highly recommend to serve it behind a NGinx or Apache reverse proxy.

The build is based on Ubuntu and will install all the required components. The following configuration steps are performed automatically:
* Reconfiguration of the base URL in `config.php`
* Generation of a new salt in `config.php`
* Generation of a self-signed certificate
* Optimization of the PHP environment (php.ini) to match the MISP recommended values
* Creation of the MySQL database
* Generation of the admin PGP key

## Config
* add your "*.crt" and "*.key" files to the ./proxy/ssl folder
If not implementing SSL (not recommended) then simply comment out the appropriate lines in the "./proxy/default.conf" file.
* Update "server_name" in default.conf file (will implement ENVIRONMENT VARIABLE in the future)

# Optional NGINX config

Included is an optional Docker Compose file 'docker-compose-nginx.yml' to spin up a reverse proxy to sit in front of MISP.

# Building your image

## Fetch files
```
$ git clone https://github.com/MISP/misp-docker
$ cd misp-docker
# Copy template.env to .env (on the root directory) and edit the environment variables at .env file
$ cp template.env .env
$ vi .env
```

## Build the containers
```
$ docker-compose build
or
$ docker-compose -f docker-compose-nginx.yml build
```

## Run containers
```
$ docker-compose up
or
$ docker-compose -f docker-compose-nginx.yml up
```

# Optional NGINX config - SSL certificates

You can create the certificates manually if they are not automatically created.

```
openssl req -new -nodes -x509 -subj "/C=BE/ST=Brussels/L=Brussels/O=CTI/CN=localhost" -days 3650 -newkey rsa:4096 -keyout proxy/ssl/misp.key -out proxy/ssl/misp.crt
```

Then rebuild the proxy container and restart al the containers.

```
docker-compose -f docker-compose-nginx.yml build --no-cache proxy
docker-compose -f docker-compose-nginx.yml up
```