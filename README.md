MISP Docker
===========

[![](https://travis-ci.org/MISP/misp-docker.svg?branch=master)](https://travis-ci.org/yaleman/misp-docker)

The files in this repository are used to create a Docker container running a [MISP](http://www.misp-project.org) ("Malware Information Sharing Platform") instance.

I rewrote the Docker file to split the components in multiple containers (which is more in the philosophy of Docker). Therefore there is no longer a Dockerfile in the root directory.

The MISP container needs at least a MySQL container to store the data. By default it listen to port 443 and port 80, which is redirected to 443.

The build is based on Ubuntu and will install all the required components, using the INSTALL script provided in the MISP repository. 

Using the Install script has the advantage that we can rely on a tested installation routine which is maintained and kept up to date. The amount of custom work to be done in the Dockerfile and run.sh files is limited to the necessary to make MISP container compliant.

The following configuration steps are performed automatically:
* Reconfiguration of the base URL in `config.php`
* Generation of a new salt in `config.php`
* Generation of a self-signed certificate
* Optimization of the PHP environment (php.ini) to match the MISP recommended values
* Creation of the MySQL database
* Generation of the admin PGP key
* Installation of misp modules 

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
$ docker-compose -f docker-compose.yml build
```

## Run containers
```
$ docker-compose up
or
$ docker-compose -f docker-compose.yml up
```
