#
# Dockerfile to customize the MISP MySQL container
#

FROM mysql/mysql-server:5.7
MAINTAINER Xavier Mertens <xavier@rootshell.be>

ARG MYSQL_MISP_PASSWORD
COPY init-misp-db.sql /docker-entrypoint-initdb.d/
RUN sed -i "s/XXXXXXXX/$MYSQL_MISP_PASSWORD/" /docker-entrypoint-initdb.d/init-misp-db.sql
