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
# Version:	0.4 (Debian)
#
# Usage: 	<$0> <namespace> {setup, cleanup} <service> 
#

source ./vnetenv.sh || { echo -e "Env not settled.\nQuit."; exit 1; }

function rsyslog_wrapper () {
	if ! test -d $VPATH/$1/ ; then
		echo -e "\n\tfolder $VPATH/$1/ is created."
		mkdir $VPATH/$1
	fi

	if ! test -d $VPATH/$1/var/ ; then
		echo -e "\tfolder $VPATH/.../var/ is created."
		mkdir $VPATH/$1/var
	fi

	if ! test -d $VPATH/$1/var/log/ ; then
		echo -e "\tfolder $VPATH/.../log/ is created."
		mkdir $VPATH/$1/var/log
	fi

	if findmnt /var/log/|grep $VPATH > /dev/null; then
		echo -e "${YELLOW}\tWarning:${RST} /var/log/ already mounted." 2>&1 > /dev/tty1
	else
		mount --bind --make-private $VPATH/$1/var/log/ /var/log/
	fi

	if ! test -d $VPATH/$1/var/run/ ; then
		echo -e "\tfolder $VPATH/.../run/ is created."
		mkdir $VPATH/$1/var/run
	fi

	if findmnt /var/run/|grep $VPATH > /dev/null; then
		echo -e "\e[33m\tWarning: /var/run/ already mounted.\e[0m"
	else
		mount --bind --make-private $VPATH/$1/var/run/ /var/run/
	fi

	if ! test -d $VPATH/$1/dev/ ; then
		echo -e "\tfolder $VPATH/.../dev/ is created."
		mkdir $VPATH/$1/dev
	fi

	if ! test -f $VPATH/$1/dev/urandom; then
		cp -n /dev/urandom $VPATH/$1/dev/
	fi

	if findmnt /dev/|grep $VPATH > /dev/null; then
		echo -e "${YELLOW}\tWarning:${RST} /dev/ already mounted."
	else
		mount --bind --make-private $VPATH/$1/dev/ /dev/	#alternatively, set Socket with
	fi								#imuxsock module within rsyslog.conf

	#service rsyslog start 
}


#call wrappers here for setup 
if [ "$2" = "setup" ]; then
	case "$3" in
		rsyslog)
			echo -ne "\n\t\tSetup rsyslog wrapper on $1 ......"
			rsyslog_wrapper $1
			echo "done."
			;;
		?)
			echo -e "${RED}Service $3 is not supported.${RST}\nQuit."
			exit;;
	esac

elif [ "$2" = "cleanup" ]; then
	case "$3" in
		rsyslog)
			echo -ne "\n\t\tClean rsyslog wrapper on $1 ....."
			test -d $VPATH/$1/var/run/ && sudo rm -rf $VPATH/$1/var/run/*
			test -d $VPATH/$1/var/log/ && sudo rm -f $VPATH/$1/var/log/*
			echo "done."
			;;
		?)
			echo -e "${RED}Service $3 is not supported.${RST}\nQuit."
			exit;;
	esac
fi

#TODO: elif [ "$4" = "start" ]; then



