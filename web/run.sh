#!/bin/bash
#
# MISP docker startup script
# Steven Goossens - steven@teamg.be

set -e
git pull /var/www/MISP

# Make MISP live
/var/www/MISP/app/Console/cake live 1
chown www-data:www-data /var/www/MISP/app/Config/config.php*

# Start supervisord
echo "Starting supervisord"
cd /
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf        
