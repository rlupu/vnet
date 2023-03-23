#!/bin/bash

#
# Copyright (C) 2023 R. Lupu @ UPB 
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Contact:	rlupu@elcom.pub.ro
#
# Version:	0.3 (Debian)
#


while getopts ":hlr" option; do
        case $option in
                h) #display help
                   echo "This script builds up simple IP virtual networks for related labs activities. "
		   echo "It is implemented based on linux namespace technology."
		   echo "Usage: vnet.sh {-h, -l, -r} | <json file>"
		   echo -e "   -h\tThis help."
		   echo -e "   -l\tList all user-defined net namespaces."
		   echo -e "   -r\tRemove all virtual nets and terminals.\n"
                   exit
		   ;;
		l) #list all existing namespaces, terms, etc.
		   nsfound=$(ip netns list)

		   if ! [ -z "$nsfound" ]; then
       			echo -n "Found namespaces: "
        		echo $nsfound
		   else
			echo "No Namespaces found."
		   fi

		   if [ $(id -u) -eq 0 ]; then
		   	screen -ls
		   fi
		   exit
		   ;;
                r) #remove whole setup 
		   if [ $(id -u) -ne 0 ]; then
			echo "Should have root privileges!"
			exit
		   fi
		   echo -n "Removing all links, net i/f, namespaces and terms ..."
		   for name in $(ip netns list | cut -d ' ' -f 1); do
		   	#ip netns exec $name ip link list type veth | \
			#	grep -zoiE "^[0-9]+[[:space:]]*:[[:space:]]*[a-z0-9]+@[a-z0-9]+[[:space:]]*" 
		   	#ip netns exec <Router> ip link del veth0_router	<-- not required.
		   	ip netns exec $name sysctl net.ipv4.ip_forward=0 2>&1 > /dev/null

                	#remove all namespaces
                   	ip netns del $name
		   done
		   pkill screen

		   #disable Internet access
		   sysctl net.ipv4.ip_forward=0 2>&1 > /dev/null
		   iptables -t nat -F POSTROUTING 
                   echo "done."
                   exit
		   ;;
        esac
done


if [ $(id -u) -ne 0 ]; then
	echo "Should have root privileges!"
	exit
fi

if [ -f "./jsonparser.sh" ] ; then
	source jsonparser.sh
else
	echo -e "json parser not found!\nQuit."
	exit
fi

if  ! ( [ $# -ne 0 ] && [ -f "./$1" ] ); then
	echo -e "json network input file not found or not specified!\nQuit."
	exit
fi


echo "Setup and configure the virtual network entities (i.e. namespaces):"
ENDPOINTS_NAMES="$(get_endpoints $1 | get_hostname)"
#echo $ENDPOINTS_NAMES

ROUTERS_NAMES="$(get_routers $1 | get_hostname)"
#echo $ROUTERS_NAMES

GATEWAY_NAME="$(get_gateways $1 | get_hostname)"
#echo $GATEWAY_NAME

${LINKED:=" "}
for name in $ENDPOINTS_NAMES; do
	IFS_NAMES="$(get_endpoint_id $name $1 | get_ifnames)"
	ip netns add $name 2> /dev/null
	if [ $? -eq 0 ]; then
		echo -e "\n\tNew $name entity setup:"
	else
		echo -e "\n\t$name..... exists.\n\tQuit."
		exit
	fi
	echo -e "\t\tCreate, attach, link and configure related network interfaces: "
	for label in $IFS_NAMES; do
		ADDR=$(get_endpoint_id $name $1 | get_address_id $label)
		MASK=$(get_endpoint_id $name $1 | get_mask_id $label)
		PEER=$(get_endpoint_id $name $1 | get_peer_id $label)
		#echo "Entity: $name; Label: "$label\_${name,,}"; Addr: $ADDR; Mask: $MASK; Peer: $PEER"
		PEER="${PEER//[[:space:]]/_}"; PEER=${PEER,,}

		#create links
		connected=false; for p in $LINKED; do if [ $p = $PEER ]; then connected=true; fi done
		if ! $connected ; then
			ip link add $label\_${name,,} type veth peer name $PEER
			ip link set $label\_${name,,} netns $name 
			echo -e "\t\t\t"$label\_${name,,} "attached and linked."
			LINKED="$LINKED "$label\_${name,,}
		fi
		#set the ip/mask!!!
		ip netns exec $name ip address add $ADDR/$MASK dev $label\_${name,,} 
		ip netns exec $name ip link set dev $label\_${name,,} up
		echo -e "\t\t\tInterface: "$label\_${name,,}"..... up"
	done
	#here, add default gw and/or routes
	echo -ne "\t\tConfigure routing tables, ..... "
	get_endpoint_id $name $1 | get_routes | \
	while read route; do
		dst=$(get_route_dst "$route")
		gw=$(get_route_gw "$route")
		if [ $dst = "any" ]; then
			ip netns exec $name ip route add default via $gw 
		else
			ip netns exec $name ip route add $dst via $gw 
		fi
	done
	echo "done."

	screen -dmS $name-term bash -c "function ip() { /sbin/ip netns exec $name /sbin/ip -c \$* ; } ; \
		function route() { /sbin/ip netns exec $name /sbin/route \$* ; } ; \
		function ifconfig() { /sbin/ip netns exec $name /sbin/ifconfig \$* ; } ; \
		function iptables() { /sbin/ip netns exec $name /sbin/iptables \$* ; } ; \
		function ping() { /sbin/ip netns exec $name /bin/ping \$* ; } ; \
		function tcpdump() { /sbin/ip netns exec $name $(which tcpdump) \$* ; } ; \
		function hping3() { /sbin/ip netns exec $name /usr/sbin/hping3 \$* ; } ; \
		function scapy3() { /sbin/ip netns exec $name /usr/bin/scapy3 \$* ; } ; \
		function wget() { /sbin/ip netns exec $name /usr/bin/wget \$* ; } ; \
		function ssh() { /sbin/ip netns exec $name /usr/bin/ssh \$* ; } ; \
		export -f ip ping route ifconfig iptables tcpdump hping3 scapy3 wget ssh; \
		export PS1=\"$name#\"; \
		bash --norc"
	echo -e "\t\t$name-term CLI......up"

done
#echo $LINKED

for name in $ROUTERS_NAMES; do
	IFS_NAMES="$(get_router_id $name $1 | get_ifnames)"
	ip netns add $name 2> /dev/null
	if [ $? -eq 0 ]; then
		echo -e "\n\tNew $name entity setup:"
	else
		echo -e "\n\t$name..... exists.\n\tQuit"
		exit
	fi
	echo -e "\t\tCreate, attach, link and configure related network interfaces: "
	for label in $IFS_NAMES; do
		ADDR=$(get_router_id $name $1 | get_address_id $label)
		MASK=$(get_router_id $name $1 | get_mask_id $label)
		PEER=$(get_router_id $name $1 | get_peer_id $label)
		#echo "Entity: $name; Label: "$label\_${name,,}"; Addr: $ADDR; Mask: $MASK; Peer: $PEER"
		PEER="${PEER//[[:space:]]/_}"; PEER=${PEER,,}

		#create links
		connected=false; for p in $LINKED; do if [ $p = $PEER ]; then connected=true; fi done
		if ! $connected ; then
			ip link add $label\_${name,,} type veth peer name $PEER
			LINKED="$LINKED "$label\_${name,,}
		fi
		ip link set $label\_${name,,} netns $name 
		#set the ip/mask!!!
		ip netns exec $name ip address add $ADDR/$MASK dev $label\_${name,,} 
		ip netns exec $name ip link set dev $label\_${name,,} up
		echo -e "\t\t\tInterface: "$label\_${name,,}"..... up"
	done
	#here, add default gw and/or routes, forwarding enabled
	echo -ne "\t\tConfigure routing tables, enable forwarding (default) ..... "
	get_router_id $name $1 | get_routes | \
	while read route; do
		dst=$(get_route_dst "$route")
		gw=$(get_route_gw "$route")
		if [ $dst = "any" ]; then
			ip netns exec $name ip route add default via $gw 
		else
			ip netns exec $name ip route add $dst via $gw 
		fi
	done
	ip netns exec $name sysctl net.ipv4.ip_forward=1 > /dev/null
	echo "done."

	screen -dmS $name-term bash -c " \
		function sysctl() { /sbin/ip netns exec $name /sbin/sysctl \$* ; } ; \
		function ip() { /sbin/ip netns exec $name /sbin/ip -c \$* ; } ; \
		function route() { /sbin/ip netns exec $name /sbin/route \$* ; } ; \
		function ifconfig() { /sbin/ip netns exec $name /sbin/ifconfig \$* ; } ; \
		function iptables() { /sbin/ip netns exec $name /sbin/iptables \$* ; } ; \
		function ping() { /sbin/ip netns exec $name /bin/ping \$* ; } ; \
		function tcpdump() { /sbin/ip netns exec $name $(which tcpdump) \$* ; } ; \
		function hping3() { /sbin/ip netns exec $name /usr/sbin/hping3 \$* ; } ; \
		function scapy3() { /sbin/ip netns exec $name /usr/bin/scapy3 \$* ; } ; \
		function wget() { /sbin/ip netns exec $name /usr/bin/wget \$* ; } ; \
		function ssh() { /sbin/ip netns exec $name /usr/bin/ssh \$* ; } ; \
		export -f sysctl ip ping route ifconfig iptables tcpdump hping3 scapy3 wget ssh; \
		export PS1=\"$name#\"; \
		bash --norc"
	echo -e "\t\t$name-term CLI......up"

done

for name in $GATEWAY_NAME; do
	IFS_NAMES="$(get_gateway_id $name $1 | get_ifnames)"
	echo -e "\n\t$name setup:"
	echo -e "\t\tCreate, attach, link and configure related network interfaces: "
	for label in $IFS_NAMES; do
		ADDR=$(get_gateway_id $name $1 | get_address_id $label)
		MASK=$(get_gateway_id $name $1 | get_mask_id $label)
		PEER=$(get_gateway_id $name $1 | get_peer_id $label)
		#echo "Entity: $name; Label: "$label\_${name,,}"; Addr: $ADDR; Mask: $MASK; Peer: $PEER"
		PEER="${PEER//[[:space:]]/_}"; PEER=${PEER,,}

		#create links
		connected=false; for p in $LINKED; do if [ $p = $PEER ]; then connected=true; fi done
		if ! $connected ; then
			ip link add $label\_${name,,} type veth peer name $PEER
			LINKED="$LINKED "$label\_${name,,}
		fi
		#set the ip/mask!!!
		ip address add $ADDR/$MASK dev $label\_${name,,} 
		ip link set dev $label\_${name,,} up
		echo -e "\t\t\tInterface: "$label\_${name,,}"..... up"
	done

	echo -ne "\t\tConfigure routing tables ..... "
	#here, add default gw and/or routes
	get_gateway_id $name $1 | get_routes | \
	while read route; do
		dst=$(get_route_dst "$route")
		gw=$(get_route_gw "$route")
		if [ $dst = "any" ]; then
			ip route add default via $gw 
		else
			ip route add $dst via $gw 
		fi
	done
	echo "done."    

	IF_INTERNET_NAME="$(get_gateway_id $name $1 | get_internet_if)"
	if ! test -z $IF_INTERNET_NAME ; then
		echo -ne "\t\tEnable forwarding, masquerading for Internet via $IF_INTERNET_NAME ..... "
		iptables -t nat -A POSTROUTING -o $IF_INTERNET_NAME -j MASQUERADE
		sysctl net.ipv4.ip_forward=1 > /dev/null
		echo "done."    
	fi	
	echo "done."    
done

echo -e "\nTerms Usage(see man screen) :\n\to GET IN: sudo screen -r <name>\n\to GET OUT: CTRL-a d\n\to KILL: exit"

