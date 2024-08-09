rm -rf /root/scripts

curl --create-dirs -o /root/scripts/pfsense_zbx.php https://raw.githubusercontent.com/rbicelli/pfsense-zabbix-template/master/pfsense_zbx.php

/usr/local/bin/php /root/scripts/pfsense_zbx.php sysversion_cron

pkg update && pkg install -y py311-speedtest-cli

curl -Lo /usr/local/lib/python3.11/site-packages/speedtest.py https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py

/usr/local/bin/php /root/scripts/pfsense_zbx.php speedtest_cron

/usr/local/bin/php /root/scripts/pfsense_zbx.php cron_cleanup

exit 0
