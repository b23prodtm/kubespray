#!/usr/bin/env bash
logger -st reboot "to complete the Access Point installation, reboot the Raspberry PI"
read -p "Do you want to reboot now [y/N] ?" REBOOT
if [ -f /etc/init.d/networking ]; then
   sudo /etc/init.d/networking restart
else
   #Work around fix netplan apply on reboot
   if [ ! -f /etc/rc.local ]; then
      printf '%s\n' "#!/bin/bash" "exit 0" | sudo tee /etc/rc.local
      sudo chmod +x /etc/rc.local
   fi
   sudo cp -f /lib/systemd/system/rc-local.service /etc/systemd/system
   printf '%s\n' "[Install]" "WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/rc-local.service
   sudo systemctl enable rc-local
   # apply once and disable
   [[ ! $(sudo cat /etc/rc.local | grep "netplan") > /dev/null ]] && sudo sed -i /"^exit"/s/^/"netplan apply\nsystemctl disable rc-local\n"/  /etc/rc.local
fi
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
source ${work_dir}init.d/init_ufw.sh
case $REBOOT in
  'y'|'Y'*) sudo reboot;;
  *)
	logger -st sysctl "restarting Access Point"
	sudo systemctl unmask hostapd.service
	sudo systemctl enable hostapd.service
	# FIX driver AP_DISABLED error : first start up interface
	sudo ifconfig wlan0 up
	sudo service hostapd start
	sleep 1
	logger -st dhcpd "restart DHCP server"
	# Restart up interface
	sudo ifconfig wlan0 up
	sudo service isc-dhcp-server restart
	sudo service isc-dhcp-server6 restart
  systemctl status hostapd.service
  systemctl status isc-dhcp-server.service
  systemctl status isc-dhcp-server6.service
  exit 0;;
esac
