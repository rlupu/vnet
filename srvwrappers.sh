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
# Version:	0.5 (Debian)
#
# Usage: 	<$0> <namespace> {setup, cleanup} <service> 
#

source ./vnetenv.sh || { echo -e "Env not settled.\nQuit."; exit 1; }

function rsyslog_setup () {
	#shared:/var/log/ /var/run/ /dev/; race_on:/var/run/rsyslog.pid /var/log/syslog /dev/log [ifnet]; 
	#	req_files: /dev/urandom;

	L_ALIGN=${L_ALIGN:="\t\t"}; unset -v DONE_ALIGN 
	echo -ne "\n${L_ALIGN}Setup rsyslog wrapper on $1 ......"
	if ! test -d $VPATH/$1/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/$1/ is created."
		mkdir $VPATH/$1
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/var/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../var/ is created."
		mkdir $VPATH/$1/var
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/var/log/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../log/ is created."
		mkdir $VPATH/$1/var/log
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if findmnt /var/log/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /var/log/ already mounted."
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		mount --bind --make-private $VPATH/$1/var/log/ /var/log/
	fi

	if ! test -d $VPATH/$1/var/run/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../run/ is created."
		mkdir $VPATH/$1/var/run
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if findmnt /var/run/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t\e[33mWarning:${RST} /var/run/ already mounted."
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		mount --bind --make-private $VPATH/$1/var/run/ /var/run/
	fi

	if ! test -d $VPATH/$1/dev/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../dev/ is created."
		mkdir $VPATH/$1/dev
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if findmnt /dev/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /dev/ already mounted."
		if ! test -f /dev/urandom ; then
			umount /dev/
			cp -nrf /dev/urandom $VPATH/$1/dev/
			mount --bind --make-private $VPATH/$1/dev/ /dev/
		fi
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		if ! test -f /dev/urandom ; then
			cp -nrf /dev/urandom $VPATH/$1/dev/
		fi
		mount --bind --make-private $VPATH/$1/dev/ /dev/	#alternatively, set Socket with
									#imuxsock module within rsyslog.conf
	fi
	echo -ne "${DONE_ALIGN:-}done."
}

function nmap_setup () {
	#shared:/dev/; race_on: none; req_files:/dev/random

	L_ALIGN=${L_ALIGN:="\t\t"}; unset -v DONE_ALIGN 
	echo -ne "\n${L_ALIGN}Setup nmap wrapper on $1 ......"
	if ! test -d $VPATH/$1/dev/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../dev/ is created." 
		mkdir $VPATH/$1/dev
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	#check whether was mounted by another wrapper
	if findmnt /dev/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /dev/ already mounted."
		if ! test -f /dev/random ; then
			umount /dev/
			cp -nrf /dev/random $VPATH/$1/dev/
			mount --bind --make-private $VPATH/$1/dev/ /dev/
		fi
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else	
		if ! test -f $VPATH/$1/dev/random ; then
			cp -nrf /dev/random $VPATH/$1/dev/		#just in case
		fi
	fi
	echo -ne "${DONE_ALIGN:-}done."
}

#function snort_setup () {
	#shared:/var/log/; race_on: ifnet; req_files:/var/log/snort/alerts; 
	#Just a placeholder for further developments 
#}


#call wrappers here for setup 
if [ "$2" = "setup" ]; then
	case "$3" in
		rsyslog)
			rsyslog_setup $1
			;;
		nmap)
			nmap_setup $1	
			;;
		?)
			echo -e "${RED}Service $3 is not supported.${RST}\nQuit."
			exit;;
	esac

elif [ "$2" = "cleanup" ]; then
	L_ALIGN=${L_ALIGN:="\t\t"}; unset -v DONE_ALIGN 
	case "$3" in
		rsyslog)
			echo -ne "\n${L_ALIGN}Clean rsyslog wrapper on $1 ....."
			#TODO: umount /var/run /var/log/ /dev/ ??? <-- ctxt-based cleanup
			#test -d $VPATH/$1/var/run/ && sudo rm -rf $VPATH/$1/var/run/*
			#test -d $VPATH/$1/var/log/ && sudo rm -rf $VPATH/$1/var/log/*
			echo -ne "${DONE_ALIGN:-}done."
			;;
		nmap)
			echo -ne "\n${L_ALIGN}Clean nmap wrapper on $1 ....."
			echo -ne "${DONE_ALIGN:-}done."
			;;
		?)
			echo -ne "${RED}Service $3 is not supported.${RST}\nQuit."
			exit;;
	esac
fi

#TODO: elif [ "$4" = "start" ]; then



