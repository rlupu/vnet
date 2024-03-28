#!/bin/bash

#
# Copyright (C) 2023, 2024 R. Lupu @ UPB, UNSTPB 
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
# Contact:	rlupu at elcom.pub.ro
#
# Version:	0.7 (Debian)
#


#include required internal modules 
source ./vnetenv.sh || { echo -e "Warning: vnet environment manager missing."; }
source ./jsonparser.sh  || { echo -e "json parser not found!\nQuit."; exit 1; }

#mandatory options with default values
VPATH=${VPATH:-"/tmp/vnet"}
VTERM=${VTERM:-"screen"}

function get_nsid() {
	ppid=$(ps ax -o pid,cmd|grep -iE $VTERM.*${1}|grep -v grep|grep -oiE ^[[:space:]]*[0-9]+|tr -d [:space:])
	while : ; do
		nsid=$(ps --ppid $ppid -o pid=)
		if ! [[ -z "$nsid" ]]; then 
			break
		fi
		sleep 1
	done
	echo $nsid
}

while getopts ":hlr" option; do
        case $option in
                h) #display help
                   echo "This script builds up simple IP virtual networks for related labs activities. "
		   echo "It is implemented based on linux namespace technology."
		   echo "Usage: vnet.sh {-h, -l, -r} | <json file>"
		   echo -e "   -h\tThis help."
		   echo -e "   -l\tList all user-defined net namespaces."
		   echo -e "   -r\tRemove all virtual nets and terminals.\n"
                   exit 0
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
		   exit 0
		   ;;
                r) #remove the entire setup 
		   if [ $(id -u) -ne 0 ]; then
			echo "Should have root privileges!"
			exit 1
		   fi

		   #first, remove terms
		   if [[ ${VTERM,,} == *screen* ]]; then
		   	pkill screen; screen -wipe > /dev/null
		   elif [[ ${VTERM,,} == *xterm* ]]; then
		   	pkill xterm > /dev/null 
		   fi

		   echo -n "Removing all links, net i/f, namespaces and associated processes ..."
		   for name in $(ip netns list | cut -d ' ' -f 1); do
			#terminate per namespace processes 
			if ! [ -z $(ip netns pids $name | tr [:cntrl:] ' ' | cut -d ' ' -f 1) ]; then
				pkill -SIGKILL --ns $(ip netns pids $name | tr [:cntrl:] ' ' | cut -d ' ' -f 1)
				#pkill rsyslogd  sshd snort nmap charon starter
			fi

		   	source ./srvwrappers.sh $name cleanup rsyslog
		   	source ./srvwrappers.sh $name cleanup ssh 
		   	source ./srvwrappers.sh $name cleanup nmap 

                	#remove this namespace
                   	ip netns del $name
		   done

		   #flush ipsec xfrm
		   read -n 1 -p "$(echo -e '\n\tFlush ipsec xfrm ? [Y/n]')" reply; reply=${reply,,}
		   if [[ $reply = "y"  || -z $reply ]]; then
		   	ip xfrm state flush && ip xfrm policy flush 
		   fi

		   #disable Internet access on Host
		   read -n 1 -p "$(echo -e '\n\tDisable Host forwarding and masquerading ? [Y/n]')" reply; 
		   reply=${reply,,}
		   if [[ $reply = "y"  || -z $reply ]]; then
		   	sysctl net.ipv4.ip_forward=0 2>&1 > /dev/null
		   	iptables -t nat -F POSTROUTING 
		   fi
                   echo -e "\ndone."

                   exit 0
		   ;;
        esac
done


if [ $(id -u) -ne 0 ]; then
	echo "Should have root privileges!"
	exit 1
fi

#check out for dependencies
if [[ ${VTERM,,} == *screen* ]]; then
	if ! command -v screen > /dev/null; then
		echo -e "screen\t - the terminals emulator not found.\nQuit."
		exit 1
	fi

elif [[ ${VTERM,,} == *xterm* ]]; then
	if ! command -v xterm > /dev/null; then
		echo -e "xterm\t - the X terminal emulator not found.\nQuit."
		exit 1
	fi
else
	echo -e "${YELLOW}VTERM value is unknown, falling back to default VTERM=screen${RST}"
	if ! command -v screen > /dev/null; then
		echo -e "screen\t - the terminals emulator not found.\nQuit."
		exit 1
	fi
	VTERM="screen"
fi

if  ! ( [ $# -ne 0 ] && [ -f "./$1" ] ); then
	echo -e "json network topology file not found/specified!\nQuit."
	exit 1
fi

if ! test -d $VPATH ; then
	echo  "folder $VPATH is created."
	mkdir $VPATH
fi


echo -ne "Setup and configure the virtual network entities (i.e. namespaces) ... "
ENDPOINTS_NAMES="$(get_endpoints $1 | get_hostname)"
#echo $ENDPOINTS_NAMES

ROUTERS_NAMES="$(get_routers $1 | get_hostname)"
#echo $ROUTERS_NAMES

GATEWAY_NAME="$(get_gateways $1 | get_hostname)"
#echo $GATEWAY_NAME

L_ALIGN=${L_ALIGN:="\t"}
${LINKED:=" "}

for name in $ENDPOINTS_NAMES; do
	IFS_NAMES="$(get_endpoint_id $name $1 | get_ifnames)"
	ip netns add $name 2> /dev/null
	if [ $? -eq 0 ]; then
		echo -ne "\n${L_ALIGN}New $name entity setup:"
	else
		echo -ne "\n${L_ALIGN}$name..... exists.\n${L_ALIGN}Quit.\n"
		exit
	fi
	echo -e "\n${L_ALIGN}\tCreate, attach, link and configure related network interfaces: "
	for label in $IFS_NAMES; do
		ADDR=$(get_endpoint_id $name $1 | get_address_id $label)
		MASK=$(get_endpoint_id $name $1 | get_mask_id $label)
		PEER=$(get_endpoint_id $name $1 | get_peer_id $label)
		#echo "\n${L_ALIGN}\tEntity: $name; Label: "$label\_${name,,}"; Addr: $ADDR; Mask: $MASK; Peer: $PEER"
		PEER="${PEER//[[:space:]]/_}"; PEER=${PEER,,}

		#create links
		connected=false; for p in $LINKED; do if [ $p = $PEER ]; then connected=true; fi done
		if ! $connected ; then
			ip link add $label\_${name,,} type veth peer name $PEER
			ip link set $label\_${name,,} netns $name 
			echo -ne "${L_ALIGN}\t\t"$label\_${name,,} "attached and linked."
			LINKED="$LINKED "$label\_${name,,}
		fi
		#set the ip/mask!!!
		ip netns exec $name ip address add $ADDR/$MASK dev $label\_${name,,} 
		ip netns exec $name ip link set dev $label\_${name,,} up
		echo -ne "\n${L_ALIGN}\t\tInterface: "$label\_${name,,}"..... up"
	done
	#here, add default gw and/or routes
	echo -ne "\n${L_ALIGN}\tConfigure routing tables ..... "
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
	echo -ne "${DONE_ALIGN:-}done."

	if [[ ${VTERM,,} == *screen* ]]; then
		screen -dmS $name-term ip netns exec $name /bin/bash -c "echo 'Welcome to $name!'; \
			source ./vnetenv.sh; \
			export PS1=\"$name#\"; \
			exec bash --norc"
	elif [[ ${VTERM,,} == *xterm* ]]; then
		xterm -title $name -bg black -fg white -sl 100 -sb -rightbar -fa Monospace -fs 10 -e 	\
			ip netns exec $name /bin/bash -c 						\
			"echo 'Welcome to $name!'; 							\
			export PS1='$name#';exec bash --norc" &
	fi

	for service in $SERVICES_WRAPPERS; do
		nsenter -n -m -w -t $(get_nsid ${name}) /bin/bash -c "source ./srvwrappers.sh $name setup $service"
	done
	echo -ne "\n${L_ALIGN}\t$name-term CLI......up"
done
#echo $LINKED

for name in $ROUTERS_NAMES; do
	IFS_NAMES="$(get_router_id $name $1 | get_ifnames)"
	ip netns add $name 2> /dev/null
	if [ $? -eq 0 ]; then
		echo -ne "\n${L_ALIGN}New $name entity setup:"
	else
		echo -ne "\n${L_ALIGN}$name..... exists.\n\tQuit.\n"
		exit
	fi
	echo -ne "\n${L_ALIGN}\tCreate, attach, link and configure related network interfaces: "
	for label in $IFS_NAMES; do
		ADDR=$(get_router_id $name $1 | get_address_id $label)
		MASK=$(get_router_id $name $1 | get_mask_id $label)
		PEER=$(get_router_id $name $1 | get_peer_id $label)
		#echo -ne "\n${L_ALIGN}\t\tEntity: $name; Label: "$label\_${name,,}"; Addr: $ADDR; Mask: $MASK; Peer: $PEER"
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
		echo -ne "\n${L_ALIGN}\t\tInterface: "$label\_${name,,}"..... up"
	done
	#here, add default gw and/or routes, forwarding enabled
	echo -ne "\n${L_ALIGN}\tConfigure routing tables, enable forwarding (default) ..... "
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
	echo -ne "${DONE_ALIGN:-}done."

	if [[ ${VTERM,,} == *screen* ]]; then
		screen -dmS $name-term ip netns exec $name /bin/bash -c "echo 'Welcome to $name!'; \
			source ./vnetenv.sh; \
			export PS1=\"$name#\"; \
			exec bash --norc"
	elif [[ ${VTERM,,} == *xterm* ]]; then
		xterm -title $name -sl 100 -sb -rightbar -fa default -fs 10 -e 	\
			ip netns exec $name /bin/bash -c 			\
			"echo 'Welcome to $name!'; 				\
			export PS1='$name#';exec bash --norc" &
	fi

	for service in $SERVICES_WRAPPERS; do
		nsenter -n -m -w -t $(get_nsid ${name}) /bin/bash -c "source ./srvwrappers.sh $name setup $service"
	done

	echo -ne "\n${L_ALIGN}\t$name-term CLI......up"

done

unset -v DONE_ALIGN
for name in $GATEWAY_NAME; do
	IFS_NAMES="$(get_gateway_id $name $1 | get_ifnames)"
	echo -ne "\n${L_ALIGN}$name entity setup:"
	echo -ne "\n${L_ALIGN}\tCreate, attach, link and configure related network interfaces: "
	for label in $IFS_NAMES; do
		ADDR=$(get_gateway_id $name $1 | get_address_id $label)
		MASK=$(get_gateway_id $name $1 | get_mask_id $label)
		PEER=$(get_gateway_id $name $1 | get_peer_id $label)
		#echo -ne "\n${L_ALIGN}\tEntity: $name; Label: "$label\_${name,,}"; Addr: $ADDR; Mask: $MASK; Peer: $PEER"
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
		echo -ne "\n${L_ALIGN}\t\tInterface: "$label\_${name,,}"..... up"
	done

	echo -ne "\n${L_ALIGN}\tConfigure routing tables ..... "
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
	echo -ne "${DONE_ALIGN:-}done."    

	IF_INTERNET_NAME="$(get_gateway_id $name $1 | get_internet_if)"
	if ! test -z $IF_INTERNET_NAME ; then
		echo -ne "\n${L_ALIGN}\tEnable forwarding, masquerading for Internet via $IF_INTERNET_NAME ..... "
		#the following doesn't work on Ubuntu, try iptables-legacy or nf_tables instead
		if command -v iptables > /dev/null; then
			iptables -t nat -A POSTROUTING -o $IF_INTERNET_NAME -j MASQUERADE
		elif command -v iptables-legacy > /dev/null; then
			iptables-legacy -t nat -A POSTROUTING -o $IF_INTERNET_NAME -j MASQUERADE
		else
			echo -ne "\n${L_ALIGN}\t\t${RED}masquerading config. failed.${RST}"	
			DONE_ALIGN="\n${L_ALIGN}\t"
		fi
		sysctl net.ipv4.ip_forward=1 > /dev/null
		echo -ne "${DONE_ALIGN:-}done."    
	fi	

	#enable net namespaces log into the host log files 
	sysctl net.netfilter.nf_log_all_netns=1 > /dev/null
done


if [[ ${VTERM,,} == *screen* ]]; then
	echo -e "\n\nVNET UI is screen(VTERM=\"screen\")."
	echo -e "Terms Usage(see man screen) :\n\to GET IN: sudo screen -r <name>\n\to GET OUT: CTRL-a d\n\to KILL: exit"
else
	echo -e "\n\nVNET UI is xterm(VTERM=\"xterm\")."
fi

echo -e "Enjoy."    

