#!/usr/bin/env bash
export work_dir=$(echo $0 | awk -F'/' '{ print $1 }')'/'
[ ! -f .hap-wiz-env.sh ] && python3 ${work_dir}../library/hap-wiz-env.py $*
source .hap-wiz-env.sh
source .hap-wiz-lib.sh
routers="option routers ${NET}.1; #hostapd wlan0"
nameservers=$(systemd-resolve --status | grep 'DNS Servers:' | awk '/(\w*\.){3}/{print $3}' | head -n 1)
nameservers6="'$(systemd-resolve -6 --status | grep 'DNS Servers:' | awk '/(\w*:){2}/{print $3}' | head -n 1)'"
function lease_blk() {
  address=$1
echo -e "#${MARKER_BEGIN}
## Example for a fixed host address try $0 --leases <hostname> [host_number]
#      host ${lease_host} { # host hostname (dhcp-leases-list)
#      hardware ethernet ${lease} # hardware ethernet 00:00:00:00:00:00 (/var/lib/dhcp/dhcpd.leases);
#        fixed-address ${address}; }
#${MARKER_END}"
}
while [ "$#" -gt 0 ]; do case $1 in
  -r*|-R*)
    sudo systemctl disable dnsmasq.service
    sudo service dnsmasq stop
    sudo service isc-dhcp-server stop
    sudo service isc-dhcp-server6 stop
    sudo systemctl disable isc-dhcp-server.service
    sudo systemctl disable isc-dhcp-server6.service
    return;;
  -h*|--help)
    echo "
Usage: $0 [-r] [--router <ipv4>] [--dns <ipv4>] [--dns6 <ipv6>]
       $0 [-l, --leases <hostname> [host_number]]
  Initializes DHCP services (without dnsmasq)
  -r
    Disable all dhcp (also with dnsmasq) services
  -l <hostname>
    Prints ethernet mac address corresponding to the specified host DHCP lease. \
    A fixed address option will be added to /etc/dhcpd/dhcp.conf, /etc/dhcpd/dhcp6.conf.
    Activate it by commenting out the host option.
  --router
    Sets up router ip address for ${NET}.0/${MASKb}
  --dns
    Add a public custom DNS address (e.g. --dns 8.8.8.8 --dns 9.9.9.9)
  --dns6
    Add a public custom DNS ipv6 address(e.g. --dns6 2001:4860:4860::8888 --dns6 2001:4860:4860::8844)
  "
    exit 1;;
  -l*|--leases*)
    lease_host=$2; lease_add=$3; lease=$(cat /var/lib/dhcp/dhcpd.leases | grep -C4 $2 | grep -m1 "hardware ethernet" | awk -F' ' '{print $3}')
    [ -z $3 ] && lease_add=${NET_start}
    [ ! -z ${lease} ] && sudo sed -i -e ${MARKERS}s/^\#// -e ${MARKER_BEGIN}d -e ${MARKER_END}d -e \$s/}// -e \$a\ "$(lease_blk $NET.$lease_add)}" /etc/dhcp/dhcpd.conf && cat /etc/dhcp/dhcpd.conf | grep -B3 "fixed-address"
    [ ! -z ${lease} ] && sudo sed -i -e ${MARKERS}s/^\#// -e ${MARKER_BEGIN}d -e ${MARKER_END}d -e \$s/}// -e \$a\ "$(lease_blk $NET6$lease_add)}" /etc/dhcp/dhcpd6.conf && cat /etc/dhcp/dhcpd6.conf | grep -B3 "fixed-address"
    return;;
  --dns)
    nameservers=$(nameservers $nameservers $2)
    shift;;
  --dns6)
    nameservers6=$(nameservers $nameservers6 $2)
    shift;;
  --router)
    routers="option routers $2;"
    shift;;
    *)
    echo -e "$0: Unknown option $1";;
esac; shift; done
echo -e "option domain-name-servers ${nameservers};

default-lease-time 600;
max-lease-time 7200;

authoritative;

log-facility local7;

subnet ${INTNET}.0 netmask ${INTMASK} {}
subnet ${NET}.0 netmask ${MASK} {
#option domain-name "wifi.localhost";
${routers}
option subnet-mask ${MASK};
option broadcast-address ${NET}.0; # dhcpd
range ${NET}.${NET_start} ${NET}.${NET_end};
${lease_blk}
}" | sudo tee /etc/dhcp/dhcpd.conf
echo -e "option dhcp6.name-servers ${nameservers6};

default-lease-time 600;
max-lease-time 7200;

authoritative;

log-facility local7;

subnet6 ${INTNET6}0/${INTMASKb6} {}
subnet6 ${NET6}0/${MASKb6} {
#option dhcp6.domain-name "wifi.localhost";
range6 ${NET6}${NET_start} ${NET6}${NET_end};
${lease_blk6}
}" | sudo tee /etc/dhcp/dhcpd6.conf
sudo sed -i -e "s/INTERFACESv4=\".*\"/INTERFACESv4=\"wlan0\"/" /etc/default/isc-dhcp-server
sudo sed -i -e "s/INTERFACESv6=\".*\"/INTERFACESv6=\"wlan0\"/" /etc/default/isc-dhcp-server
sudo cat /etc/default/isc-dhcp-server
sleep 1
logger -st dhcpd "start DHCP server"
sudo systemctl unmask isc-dhcp-server.service
sudo systemctl enable isc-dhcp-server.service
sudo service isc-dhcp-server start
sudo systemctl unmask isc-dhcp-server6.service
sudo systemctl enable isc-dhcp-server6.service
sudo service isc-dhcp-server6 start
