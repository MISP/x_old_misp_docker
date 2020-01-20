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
                ls /tmp/key
                echo "importing key"; sudo -u www-data gpg --batch --homedir /var/www/MISP/.gnupg --passphrase $PASSPHRASE_GPG --import /tmp/key/* | true
                echo "key imported"
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

# Server Settings & Maintenance
#
$CAKE Admin setSetting "MISP.baseurl" "$MISP_BASEURL" 2> /dev/null | true
$CAKE Admin setSetting "MISP.external_baseurl" "$MISP_BASEURL" 2> /dev/null | true
$CAKE Admin setSetting "MISP.live" true 2> /dev/null | true
$CAKE Admin setSetting "MISP.language" "eng" 2> /dev/null | true
$CAKE Admin setSetting "MISP.email" "$MISP_EMAIL" 2> /dev/null | true
# Org 0 - None
# Org 1 - ORGNAME
# Org 2 does not exist on first install. The first org created is assigned Org ID 2.
$CAKE Admin setSetting "MISP.host_org_id" 2 2> /dev/null | true
# MISP.default_event_distribution:
# 1 - This Community Only
# 2 - Connected Communities
# 3 - All Commmunities
$CAKE Admin setSetting "MISP.default_event_distribution" 1 2> /dev/null | true
$CAKE Admin setSetting "MISP.default_event_tag_collection" 0 2> /dev/null | true
$CAKE Admin setSetting "MISP.proposals_block_attributes" false 2> /dev/null | true
$CAKE Admin setSetting "MISP.redis_host" "$REDISHOST" 2> /dev/null | true
$CAKE Admin setSetting "MISP.redis_port" $REDISPORT 2> /dev/null | true
$CAKE Admin setSetting "MISP.redis_database" $REDISDB 2> /dev/null | true
$CAKE Admin setSetting "MISP.redis_password" $REDISPASSWORD 2> /dev/null | true
# We're not using a python venv in the docker container.
$CAKE Admin setSetting "MISP.python_bin" /usr/bin/python3 2> /dev/null | true
$CAKE Admin setSetting "MISP.ssdeep_correlation_threshold" "40" 2> /dev/null | true
$CAKE Admin setSetting "MISP.org" "$MISP_org" 2> /dev/null | true
$CAKE Admin setSetting "MISP.contact" "$MISP_EMAIL" 2> /dev/null | true
$CAKE Admin setSetting "MISP.extended_alert_subject" false 2> /dev/null | true
# TODO: test param value is undefined
#$CAKE Admin setSetting "MISP.default_event_threat_level" 4 2> /dev/null | true
$CAKE Admin setSetting "MISP.default_event_threat_level" 4 2> /dev/null | true
# Logging
$CAKE Admin setSetting "MISP.log_client_ip" true 2> /dev/null | true
$CAKE Admin setSetting "MISP.log_auth" true 2> /dev/null | true
# We want delegation so ISAO members can be anonymous if they so chose.
$CAKE Admin setSetting "MISP.delegation" true 2> /dev/null | true
# TODO: test performance hit
$CAKE Admin setSetting "MISP.showCorrelationsOnIndex" true 2> /dev/null | true
$CAKE Admin setSetting "MISP.showProposalsCountOnIndex" true 2> /dev/null | true
$CAKE Admin setSetting "MISP.showSightingsCountOnIndex" true 2> /dev/null | true
$CAKE Admin setSetting "MISP.showDiscussionsCountOnIndex" true 2> /dev/null | true
# Only org admins and admins should be editing user settings.
$CAKE Admin setSetting "MISP.disableUserSelfManagement" true 2> /dev/null | true

# Encryption Settings
#
# Config for GPG
$SUDO_WWW $CAKE Admin setSetting "GnuPG.onlyencrypted" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "GnuPG.email" $MISP_ADMIN_EMAIL 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "GnuPG.homedir" /var/www/MISP/.gnupg 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "GnuPG.binary" /usr/bin/gpg 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "GnuPG.password" $PASSPHRASE_GPG 2> /dev/null | true

# Security Settings
#
$CAKE Admin setSetting "Security.salt" "$MISP_salt" 2> /dev/null | true

# Plugin Settings
#
# ZeroMQ
$CAKE Admin setSetting "Plugin.ZeroMQ_port" "$ZeroMQ_port" 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_event_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_object_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_object_reference_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_attribute_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_sighting_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_user_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_organisation_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_host" "$REDISHOST" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_port" $REDISPORT 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_database" 1 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_redis_namespace" "mispq" 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_include_attachments" false 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_tag_notifications_enable" true 2> /dev/null | true
$CAKE Admin setSetting "Plugin.ZeroMQ_audit_notifications_enable" true 2> /dev/null | true
#Enabling zmq prior launching misp will fail and cannot recover..
$CAKE Admin setSetting "Plugin.ZeroMQ_enable" false 2> /dev/null | true

# Enrichments
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_enable" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_hover_enable" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_timeout" 300  2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_hover_timeout" 150 2> /dev/null | true
# TODO:"Investigate why the next one fails"
#$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_asn_history_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_cve_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_dns_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_btc_steroids_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_ipasn_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_yara_syntax_validator_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_yara_query_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_pdf_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_docx_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_xlsx_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_pptx_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_ods_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_odt_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_sigma_queries_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_sigma_syntax_validator_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_stix2_pattern_syntax_validator_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_url" "$MISP_MODULE_SERVICE" 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_port" 6666 2> /dev/null | true

# Import Modules
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_services_enable" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_services_url" "$MISP_MODULE_SERVICE" 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_services_port" 6666 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_timeout" 300 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_ocr_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_mispjson_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_openiocimport_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_threatanalyzer_import_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_csvimport_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_joe_import_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Import_cuckooimport_enabled" true 2> /dev/null | true

# Export Modules
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_services_enable" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_services_url" "$MISP_MODULE_SERVICE" 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_services_port" 6666 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_timeout" 300 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_pdfexport_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_enable" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Export_osqueryexport_enabled" true 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Enrichment_services_enable" true 2> /dev/null | true

# Sightings
$SUDO_WWW $CAKE Admin setSetting "Plugin.Sightings_policy" 2 2> /dev/null | true
$SUDO_WWW $CAKE Admin setSetting "Plugin.Sightings_sighting_db_enable" 1 2> /dev/null | true

sed -i "s,'host_org_id' => 1,'host_org_id' => 2," /var/www/MISP/app/Config/config.php

# Configure POSTFIX
sudo postconf -e "relayhost = [email-smtp.us-east-1.amazonaws.com]:587" \
"smtp_sasl_auth_enable = yes" \
"smtp_sasl_security_options = noanonymous" \
"smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" \
"smtp_use_tls = yes" \
"smtp_tls_security_level = encrypt" \
"smtp_tls_note_starttls_offer = yes" \
"inet_interfaces = all" \
"myorigin = /etc/mailname"

echo "ubisoft.com" > /etc/mailname

echo "[email-smtp.us-east-1.amazonaws.com]:587 $SMTP_USER:$SMTP_PASSWORD" > /etc/postfix/sasl_passwd
sudo postmap hash:/etc/postfix/sasl_passwd
sudo chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo chmod 0600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
sudo postconf -e 'smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt'

sed -i 's/inet_protocols = all/inet_protocols = ipv4/g' /etc/postfix/main.cf
sed -i 's/inet_interfaces = all/inet_interfaces = loopback-only/g' /etc/postfix/main.cf

# Set canonical to only send email as MISP_ADMIN_EMAIL
echo "canonical_maps = regexp:/etc/postfix/canonical" >> /etc/postfix/main.cf
echo "// $MISP_ADMIN_EMAIL" > /etc/postfix/canonical

# Fix DNS issue
cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf


sudo postfix stop; sudo postfix start; sudo postfix reload

# Start supervisord
echo "Starting supervisord"
cd /
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
