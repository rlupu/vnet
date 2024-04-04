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
# Usage: 	<$0> <namespace> {setup, cleanup} <service> 
#

source ./vnetenv.sh || { echo -e "Env not settled.\nQuit."; exit 1; }
VPATH=${VPATH:-"/tmp/vnet"}


function rsyslog_setup () {
	#shared:/var/log/ /var/run/ /run/ /dev/; race_on:/var/run/rsyslog.pid /var/log/syslog /dev/log [ifnet]; 
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

	if ! test -d $VPATH/$1/dev/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../dev/ is created."
		mkdir $VPATH/$1/dev
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/run/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../run/ is created."
		mkdir $VPATH/$1/run
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/var/log/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../log/ is created."
		mkdir $VPATH/$1/var/log
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -h $VPATH/$1/var/run ; then
		echo -ne "\n${L_ALIGN}\tsymlink /var/run to /run/ is created."
		ln -s $VPATH/$1/run/ $VPATH/$1/var/run
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	#second, populate with req. files + mount folders
	if findmnt -rno SOURCE /var/log/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /var/log/ already mounted."
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		mount --bind --make-private $VPATH/$1/var/log/ /var/log/
	fi

	if findmnt -rno SOURCE /var/run/|grep $VPATH > /dev/null; then		#TODO: work directly on /run
		echo -ne "\n${L_ALIGN}\t\e[33mWarning:${RST} /var/run/ already mounted."
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		mount --bind --make-private $VPATH/$1/var/run /var/run/
	fi

	if findmnt -nro SOURCE /dev/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /dev/ already mounted."
		if ! test -c /dev/urandom ; then
			#umount /dev/
			#cp -nr /dev/urandom $VPATH/$1/dev/
			mknod -m 444 $VPATH/$1/dev/urandom c 1 9
			#cp -nr /dev/null $VPATH/$1/dev/
			mknod -m 666 $VPATH/$1/dev/null c 1 3
			#mount --bind --make-private $VPATH/$1/dev/ /dev/
		fi
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		if ! test -c /dev/urandom ; then
			#cp -nr /dev/urandom $VPATH/$1/dev/
			mknod -m 444 $VPATH/$1/dev/urandom c 1 9
			cp -nr /dev/null $VPATH/$1/dev/
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

	if ! test -d $VPATH/$1/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/$1/ is created."
		mkdir $VPATH/$1
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/dev/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../dev/ is created." 
		mkdir $VPATH/$1/dev
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	#check whether was mounted by another wrapper
	if findmnt -nro SOURCE /dev/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /dev/ already mounted."
		if ! test -c /dev/random ; then
			#umount /dev/
			#cp -nr /dev/random $VPATH/$1/dev/
			mknod -m 444 $VPATH/$1/dev/random c 1 8 
			#cp -nr /dev/null $VPATH/$1/dev/
			mknod -m 666 $VPATH/$1/dev/null c 1 3
			#mount --bind --make-private $VPATH/$1/dev/ /dev/
		fi
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else	
		if ! test -c $VPATH/$1/dev/random ; then
			#cp -nrf /dev/random $VPATH/$1/dev/		#just in case will be mounted
			mknod -m 444 $VPATH/$1/dev/random c 1 8 
			cp -nr /dev/null $VPATH/$1/dev/
		fi							#by another wrapper
	fi
	echo -ne "${DONE_ALIGN:-}done."
}

function snort_setup () {
	#shared:/var/log/; race_on: ifnet; req_files:/var/log/snort/alerts; 
	#Just a placeholder for further developments 
	cd .
}

function ssh_setup () {
	#shared: /dev/pts; race_on: ; req_files:/dev/ptmx, /dev/pts/ptmx [mounted]

	L_ALIGN=${L_ALIGN:="\t\t"}; unset -v DONE_ALIGN 
	echo -ne "\n${L_ALIGN}Setup ssh wrapper on $1 ......"

	if ! command -v ssh-askpass > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${RED}Error:${RST} ssh-askpass not installed."
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
		exit 1
	fi

	if ! test -d $VPATH/$1/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/$1/ is created."
		mkdir $VPATH/$1
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/dev/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../dev/ is created."
		mkdir $VPATH/$1/dev
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	#see tldp site for how to populate /dev
	if ! test -c $VPATH/$1/dev/tty ; then
		mknod -m 666 $VPATH/$1/dev/tty c 5 0 
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -c $VPATH/$1/dev/console ; then
		mknod -m 622 $VPATH/$1/dev/console c 5 1 
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	#if ! test -p $VPATH/$1/dev/xconsole ; then
	#	mkfifo -m 644 $VPATH/$1/dev/xconsole 
	#	DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	#fi

	if ! test -c $VPATH/$1/dev/ptmx ; then
		mknod -m 666 $VPATH/$1/dev/ptmx c 5 2
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/dev/pts ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../dev/pts is created."
		mkdir $VPATH/$1/dev/pts
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi
	
	#check whether was mounted by another wrapper
	if findmnt -rno SOURCE /dev/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /dev/ already mounted."
		if ! findmnt -nr -o SOURCE /dev/pts|grep $VPATH > /dev/null; then
			mount -t devpts $VPATH/$1/dev/pts /dev/pts 
		fi
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		mount --bind --make-private $VPATH/$1/dev/ /dev/
		if ! findmnt -nr -o SOURCE /dev/pts|grep $VPATH > /dev/null; then
			mount -t devpts $VPATH/$1/dev/pts /dev/pts 
		fi
	fi
	echo -ne "${DONE_ALIGN:-}done."
}

function strongswan_setup () {
	#shared:/etc/ /var/ /var/run /run/;  race_on:/var/lock /var/run/charon.pid /etc/ipsec.conf 
	#	?/var/log/? ?/dev/? ?/var/log/syslog? ?ifnet?; req_files: ?/dev/urandom?;
	#Assumed: ipsec tool for IPSec system control

	L_ALIGN=${L_ALIGN:="\t\t"}; unset -v DONE_ALIGN 
	echo -ne "\n${L_ALIGN}Setup strongswan wrapper on $1 ......"

	if ! command -v ipsec > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${RED}Error:${RST} ipsec tool not installed."
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
		exit 1
	fi

	#first, clone the shared folders + raced with the others wrappers
	if ! test -d $VPATH/$1/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/$1/ is created."
		mkdir $VPATH/$1
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/etc/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/... /etc/ is created."
		mkdir $VPATH/$1/etc
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/var/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../var/ is created."
		mkdir $VPATH/$1/var
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/run/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../run/ is created."
		mkdir $VPATH/$1/run
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -d $VPATH/$1/run/lock/ ; then
		echo -ne "\n${L_ALIGN}\tfolder $VPATH/.../run/lock/ is created."
		mkdir $VPATH/$1/run/lock
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -h $VPATH/$1/var/run ; then
		echo -ne "\n${L_ALIGN}\tsymlink $VPATH/$1/var/run to $VPATH/$1/run/ is created."
		ln -s $VPATH/$1/run/ $VPATH/$1/var/run 
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if ! test -h /var/lock ; then
		echo -ne "\n${L_ALIGN}\tsymlink /var/lock to $VPATH/.../var/lock is created."
		ln -s $VPATH/$1/run/lock /var/lock
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	fi

	if findmnt -nro SOURCE /var/run/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t\e[33mWarning:${RST} /var/run/ already mounted."
		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		mount --bind --make-private $VPATH/$1/var/run /var/run/
	fi


	#second, populate clone folders with req_files + mount them
	#check whether was mounted by another wrapper
	if findmnt -nro SOURCE /etc/|grep $VPATH > /dev/null; then
		echo -ne "\n${L_ALIGN}\t${YELLOW}Warning:${RST} /etc/ already mounted."
		if ! test -f /etc/ipsec.conf ; then
			umount /etc/
			cp -nr /etc/ipsec.conf $VPATH/$1/etc/		#bring it from installation folder
			mount --bind --make-private $VPATH/$1/etc/ /etc/
		fi

		if ! test -f /etc/ipsec.secrets ; then
			umount /etc/
			cp -nr /etc/ipsec.secrets $VPATH/$1/etc/	#idem
			mount --bind --make-private $VPATH/$1/etc/ /etc/
		fi

		DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
	else
		if ! test -d /etc/netns/ ; then
			echo -ne "\n${L_ALIGN}\tfolder /etc/netns/ is created."
			mkdir /etc/netns
			DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
		fi

		if ! test -d /etc/netns/$1/ ; then
			echo -ne "\n${L_ALIGN}\tfolder /etc/netns/$1/ is created."
			mkdir /etc/netns/$1
			DONE_ALIGN=${DONE_ALIGN:="\n${L_ALIGN}"}
		fi

		if ! test -f /etc/netns/$1/ipsec.conf ; then
			cp -nrf /etc/ipsec.conf /etc/netns/$1/
		fi

		if ! test -f /etc/netns/$1/ipsec.secrets ; then
			cp -nr /etc/ipsec.secrets /etc/netns/$1/
		fi

		if ! test -f $VPATH/$1/etc/ipsec.conf ; then		#just in case will be mounted
			cp -nr /etc/ipsec.conf $VPATH/$1/etc/		#by another wrapper instance 
		fi

		if ! test -f $VPATH/$1/etc/ipsec.secrets ; then		#just in case will be mounted
			cp -nr /etc/ipsec.secrets $VPATH/$1/etc/	#by another wrapper instance
		fi

		if ! test -d /etc/netns/$1/ipsec.d/ ; then
			mkdir -m 755 /etc/netns/$1/ipsec.d
			mkdir -m 700 /etc/netns/$1/ipsec.d/private
			mkdir -m 755 /etc/netns/$1/ipsec.d/certs
			mkdir -m 755 /etc/netns/$1/ipsec.d/cacerts

		else 
			if ! test -d /etc/netns/$1/ipsec.d/private ; then
				mkdir -m 700 /etc/netns/$1/ipsec.d/private
			fi

			if ! test -d /etc/netns/$1/ipsec.d/certs ; then
				mkdir -m 700 /etc/netns/$1/ipsec.d/certs
			fi

			if ! test -d /etc/netns/$1/ipsec.d/cacerts ; then
				mkdir -m 700 /etc/netns/$1/ipsec.d/cacerts
			fi
		fi
	fi

	echo -ne "${DONE_ALIGN:-}done."
}

#call wrappers here for setup 
if [ "$2" = "setup" ]; then
	case "$3" in
		rsyslog)
			rsyslog_setup $1
			;;
		nmap)
			nmap_setup $1	
			;;
		ssh)
			ssh_setup $1
			;;
		snort)
			snort_setup $1
			;;
		strongswan)
			strongswan_setup $1
			;;
		?)
			echo -e "${RED}Service $3 is not supported.${RST}\nQuit."
			exit;;
	esac

elif [ "$2" = "cleanup" ]; then
	L_ALIGN=${L_ALIGN:="\t"}; unset -v DONE_ALIGN 
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
		ssh)
			echo -ne "\n${L_ALIGN}Clean ssh wrapper on $1 ....."
			echo -ne "${DONE_ALIGN:-}done."
			;;
		snort)
			echo -ne "\n${L_ALIGN}Clean snort wrapper on $1 ....."
			echo -ne "${DONE_ALIGN:-}done."
			;;
		strongswan)
			echo -ne "\n${L_ALIGN}Clean strongswan wrapper on $1 ....."
			echo -ne "${DONE_ALIGN:-}done."
			;;
		?)
			echo -ne "${RED}Service $3 is not supported.${RST}\nQuit."
			exit;;
	esac
fi

#TODO: elif [ "$4" = "start" ]; then



