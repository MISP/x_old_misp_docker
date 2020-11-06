FROM nginx:1.18

#  default conf for proxy service
COPY ./default.conf /etc/nginx/conf.d/default.conf

#  Proxy and SSL configurations
COPY ./includes/ /etc/nginx/includes/

# Proxy SSL certificates
COPY ./ssl/ /etc/ssl/certs/nginx/
