#!/bin/bash
#
# MISP docker startup script
# Xavier Mertens <xavier@rootshell.be>
#
# 2017/05/17 - Created
# 2017/05/31 - Fixed small errors
# 2019/10/17 - Use built-in mysql docker DB creation and use std env names (dafal)
#

set -e

if [ -r /.firstboot.tmp ]; then
        echo "Container started for the fist time. Setup might time a few minutes. Please wait..."
        echo "(Details are logged in /tmp/install.log)"
        export DEBIAN_FRONTEND=noninteractive

        # If the user uses a mount point restore our files
        if [ ! -d /var/www/MISP/app ]; then
                echo "Restoring MISP files..."
                cd /var/www/MISP
                tar xzpf /root/MISP.tgz
                rm /root/MISP.tgz
        fi

        echo "Configuring postfix"
        if [ -z "$POSTFIX_RELAY_HOST" ]; then
                echo "POSTFIX_RELAY_HOST is not set, please configure Postfix manually later..."
        else
                postconf -e "relayhost = $POSTFIX_RELAY"
        fi

        # Fix timezone (adapt to your local zone)
        if [ -z "$TIMEZONE" ]; then
                echo "TIMEZONE is not set, please configure the local time zone manually later..."
        else
                echo "$TIMEZONE" > /etc/timezone
                dpkg-reconfigure -f noninteractive tzdata >>/tmp/install.log
        fi

        echo "Creating MySQL database"

        # Check MYSQL_HOST
        if [ -z "$MYSQL_HOST" ]; then
                echo "MYSQL_HOST is not set. Aborting."
                exit 1
        fi

		# Waiting for DB to be ready
		while ! mysqladmin ping -h"$MYSQL_HOST" --silent; do
		    sleep 5
			echo "Waiting for database to be ready..."
		done

        # Set MYSQL_PASSWORD
        if [ -z "$MYSQL_PASSWORD" ]; then
                echo "MYSQL_PASSWORD is not set, use default value 'misp'"
                MYSQL_PASSWORD=misp
        else
                echo "MYSQL_PASSWORD is set to '$MYSQL_PASSWORD'"
        fi

        ret=`echo 'SHOW TABLES;' | mysql -u $MYSQL_USER --password="$MYSQL_PASSWORD" -h $MYSQL_HOST -P 3306 $MYSQL_DATABASE # 2>&1`
        if [ $? -eq 0 ]; then
                echo "Connected to database successfully!"
                found=0
                for table in $ret; do
                        if [ "$table" == "attributes" ]; then
                                found=1
                        fi
                done
                if [ $found -eq 1 ]; then
                        echo "Database misp available"
                else
                        echo "Database misp empty, creating tables ..."
                        ret=`mysql -u $MYSQL_USER --password="$MYSQL_PASSWORD" $MYSQL_DATABASE -h $MYSQL_HOST -P 3306 2>&1 < /var/www/MISP/INSTALL/MYSQL.sql`
                        if [ $? -eq 0 ]; then
                            echo "Imported /var/www/MISP/INSTALL/MYSQL.sql successfully"
                        else
                            echo "ERROR: Importing /var/www/MISP/INSTALL/MYSQL.sql failed:"
                            echo $ret
                        fi
                fi
        else
                echo "ERROR: Connecting to database failed:"
                echo $ret
        fi

        # MISP configuration
        echo "Creating MISP configuration files"
        cd /var/www/MISP/app/Config
        cp -a database.default.php database.php
        sed -i "s/localhost/$MYSQL_HOST/" database.php
        sed -i "s/db\s*login/$MYSQL_USER/" database.php
        sed -i "s/8889/3306/" database.php
        sed -i "s/db\s*password/$MYSQL_PASSWORD/" database.php

        # Fix the base url
        if [ -z "$MISP_BASEURL" ]; then
                echo "No base URL defined, don't forget to define it manually!"
        else
                echo "Fixing the MISP base URL ($MISP_BASEURL) ..."
                sed -i "s,'baseurl'                        => '','baseurl'                        => '$MISP_BASEURL'," /var/www/MISP/app/Config/config.php
        fi

        # Generate the admin user PGP key
        echo "Creating admin GnuPG key"
        if [ -z "$MISP_ADMIN_EMAIL" -o -z "$MISP_ADMIN_PASSPHRASE" ]; then
                echo "No admin details provided, don't forget to generate the PGP key manually!"
        else

                echo "Assuming we have a GPG key at /tmp/key.asc"
                sudo -u www-data gpg --import /tmp/key.asc >>/tmp/install.log
		sudo -u www-data gpg --homedir /var/www/MISP/.gnupg --export --armor $MISP_ADMIN_EMAIL > /var/www/MISP/app/webroot/gpg.asc
        fi

        # Display tips
        cat <<__WELCOME__
Congratulations!
Your MISP docker has been successfully booted for the first time.
Don't forget:
- Reconfigure postfix to match your environment
- Change the MISP admin email address to $MISP_ADMIN_EMAIL

__WELCOME__
        rm -f /.firstboot.tmp
fi

echo "Configure MISP"
# Configure MISP config
CAKE="/var/www/MISP/app/Console/cake"

$CAKE Admin setSetting MISP.baseurl "$MISP_BASEURL" 2> /dev/null | true
$CAKE Admin setSetting Plugin.ZeroMQ_port "$ZeroMQ_port" 2> /dev/null | true
$CAKE Admin setSetting Security.salt "$MISP_salt" 2> /dev/null | true

$CAKE Admin setSetting "Plugin.ZeroMQ_event_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_object_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_object_reference_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_attribute_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_sighting_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_user_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_organisation_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_host" "localhost" 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_port" 6379 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_database" 1 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_namespace" "mispq" 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_include_attachments" false 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_tag_notifications_enable" false 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_audit_notifications_enable" false 2> /dev/null | true

#Enabling zmq prior launching misp will fail and cannot recover..
$CAKE Admin setSetting Plugin.ZeroMQ_enable false | true

$CAKE Admin setSetting MISP.python_bin /usr/bin/python3

# Enable Enrichment, set better timeouts
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_enable" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_hover_enable" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_timeout" 300
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_hover_timeout" 150
# TODO:"Investigate why the next one fails"
#$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_asn_history_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_cve_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_dns_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_btc_steroids_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_ipasn_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_yara_syntax_validator_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_yara_query_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_pdf_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_docx_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_xlsx_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_pptx_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_ods_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_odt_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_url" "http://127.0.0.1"
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_port" 6666

# Enable Import modules, set better timeout
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_services_enable" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_services_url" "http://127.0.0.1"
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_services_port" 6666
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_timeout" 300
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_ocr_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_mispjson_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_openiocimport_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_threatanalyzer_import_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_csvimport_enabled" true

# Enable Export modules, set better timeout
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_services_enable" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_services_url" "http://127.0.0.1"
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_services_port" 6666
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_timeout" 300
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_pdfexport_enabled" true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_enable" true

# Config for GPG
$SUDO_WWW $CAKE Admin setSetting "GnuPG.email" $MISP_ADMIN_EMAIL
$SUDO_WWW $CAKE Admin setSetting "GnuPG.homedir" /var/www/MISP
$SUDO_WWW $CAKE Admin setSetting "GnuPG.binary" /usr/bin/gpg
$SUDO_WWW $CAKE Admin setSetting "GnuPG.email" $MISP_ADMIN_EMAIL
$SUDO_WWW $CAKE Admin setSetting "GnuPG.password" $PASSPHRASE_GPG

sed -i "s,'host_org_id' => 1,'host_org_id' => 2," /var/www/MISP/app/Config/config.php

# Start supervisord
echo "Starting supervisord"
cd /
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
