MISP Docker
===========

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


# Optional NGINX config

Included is an optional Docker Compose file 'docker-compose-nginx.yml' to spin up a reverse proxy to sit in front of MISP.

## Config
* add your "*.crt" and "*.key" files to the ./misp-proxy/ssl folder
If not implementing SSL (not recommended) then simply comment out the appropriate lines in the "./misp-proxy/default.conf" file.
* Update "server_name" in default.conf file (will implement ENVIRONMENT VARIABLE in the future)


# Building your image

## Fetch files
```
$ git clone https://github.com/MISP/misp-docker
$ cd misp-docker
```
## Fix your environment
Edit the docker-compose.yml and change the following environment variables:
* MYSQL_DATABASE
* MYSQL_USER
* MYSQL_PASSWORD
* MYSQL_ROOT_PASSWORD
* MYSQL_MISP_PASSWORD
* MISP_ADMIN_PASSPHRASE
* Changed the volumes to match your local filesystem

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
