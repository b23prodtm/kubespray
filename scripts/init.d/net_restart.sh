#!/bin/bash
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
[ ! -f .hap-wiz-env.sh ] && python3 ${work_dir}../library/hap-wiz-env.py $*
source .hap-wiz-env.sh
logger -st reboot "to complete the Access Point installation, reboot the Raspberry PI"
read -p "Do you want to reboot now [y/N] ?" REBOOT
if [ -f /etc/init.d/networking ]; then
   sudo /etc/init.d/networking restart
else
   logger -st 'rc.local' 'Work around fix netplan apply on reboot'
   if [ ! -f /etc/rc.local ]; then
      printf '%s\n' "#!/bin/bash" "exit 0" | sudo tee /etc/rc.local
      sudo chmod +x /etc/rc.local
   fi
   sudo cp -f /lib/systemd/system/rc-local.service /etc/systemd/system
   printf '%s\n' "[Install]" "WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/rc-local.service
   sudo systemctl enable rc-local
   # apply once and disable
   sed -i -e s/"${MARKERS}"//g -e /"^exit"/s/"^"/"${MARKER_BEGIN}\n\
netplan apply\n\
systemctl restart hostapd\n\
netplan apply\n\
dhclient ${INT}\n\
ip link set dev wlan0 up\n\
dhclient br0\n\
systemctl restart isc-dhcp-server\n\
systemctl restart isc-dhcp-server6\n\
${MARKER_END}\n"/ /etc/rc.local
   logger -st sed "/etc/rc.local added command lines"
   cat /etc/rc.local
fi
source ${work_dir}init.d/init_ufw.sh
case $REBOOT in
  'y'|'Y'*) sudo reboot;;
  *)
	logger -st sysctl "restarting Access Point"
	sudo systemctl unmask hostapd.service
	sudo systemctl enable hostapd.service
	# FIX driver AP_DISABLED error : first start up interface
	sudo netplan apply
	sudo service hostapd start
	sleep 1
	logger -st dhcpd "restart DHCP server"
	# Restart up interface
	sudo dhclient ${INT}
	sudo ip link set dev wlan0 up
	sudo dhclient br0
	sudo service isc-dhcp-server restart
	sudo service isc-dhcp-server6 restart
	systemctl status hostapd.service
	systemctl status isc-dhcp-server.service
	systemctl status isc-dhcp-server6.service
	exit 0;;
esac
