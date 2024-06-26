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
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# Contact:	rlupu at elcom.pub.ro
#
# Version:	0.5 (Debian)
#


#####options setup#####
VPATH="/tmp/vnet"
#VTERM="screen" 		
VTERM="xterm"
VTERM_FS=12
#services wrappers defined: rsyslog nmap ssh strongswan
SERVICES_WRAPPERS="strongswan rsyslog"

#####constants definition######
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
RST='\e[0m'

#####vnet commands definitions#####
function vterm ( ) {
	if [ $# -ne 0 ]; then
		sudo screen -r $1
	else
		echo -e "Usage:\n\tvterm <name>"
		echo "Names: $(sudo ip netns list | cut -d ' '  -f 1 | tr '\n' ' ')" || echo "???"
		#TODO: xterm case to be handled here
	fi
}

function ip() { 
	/sbin/ip -c $*  
} 

function ls() {
	/bin/ls --color $*
}

export -f vterm ip ls

#####vnet environment setup#####
#export PS1='Host$'

