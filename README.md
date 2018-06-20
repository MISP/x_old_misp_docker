MISP Docker
===========

The files in this repository are used to create a Docker container running a [MISP](http://www.misp-project.org) ("Malware Information Sharing Platform") instance.

I rewrote the Docker file to split the components in multiple containers (which is more in the philosophy of Docker).

The MISP container needs at least a MySQL container to store the data. By default it listen to port 80. I highly recommend to serve it behind a NGinx or Apache reverse proxy.

The build is based on Ubuntu and will install all the required components. The following configuration steps are performed automatically:
* Reconfiguration of the base URL in `config.php`
* Generation of a new salt in `config.php`
* Generation of a self-signed certificate
* Optimization of the PHP environment (php.ini) to match the MISP recommended values
* Creation of the MySQL database
* Generation of the admin PGP key

# Building your image

## Fetch files
```
# git clone https://github.com/xme/misp-docker
# cd misp-docker
docker build -t misp .
```
## Fix your environment
Edit the docker-compose.yml and change the following environment variables:
* MYSQL_ROOT_PASSWORD
* MYSQL_MISP_PASSWORD
* MISP_ADMIN_PASSPHRASE
* Changed the volumes to match your local filesystem

## Build the containers
```
# docker-compose build
```
