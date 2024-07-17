#/bin/bash

# fixes the issue where docker blocks the internet connection for virtual machines
#  this is currently set to run every 30 seconds via root crontab using lib/30_second_loop.sh
systemctl is-active --quiet docker && sudo iptables -I FORWARD -i br0 -o br0 -j ACCEPT
