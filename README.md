MISP Docker
===========

The files in this repository are used to create a Docker container running a [MISP](http://www.misp-project.org) ("Malware Information Sharing Platform") instance.

I  rewrote the Docker file to split the components in multiple containers (which is more in the philosophy of Docker).

The MISP container needs at least a MySQL container to store the data. By default it listen to port 80. I highly recommend to serve it behind a NGinx or Apache reverse proxy.

The build is based on Ubuntu and will install all the required components. The following configuration steps are performed automatically:
* Reconfiguration of the base URL in `config.php`
* Generation of a new salt in `config.php`
* Generation of a self-signed certificate
* Optimization of the PHP environment (php.ini) to match the MISP recommended values
* Creation of the MySQL database
* Generation of the admin PGP key

# Building the image

```
# git clone https://github.com/xme/misp-docker
# cd misp-docker
# docker build -t misp .
```

# Configuring MySQL container

```
(in mysql console from database root user)
> USE mysql;
> UPDATE user SET host='%' WHERE host='localhost';
> FLUSH PRIVILEGES;
```

# Running the image
Use the docker-compose file provided as example.
