#!/usr/bin/env bash

[ -z "$CONNECTION_UUID" ] && exit 0 # add logic to server

INTERFACE="$1"
ACTION="$2"

case $ACTION in
    up)
	if ps -acx | grep -q "[s]shd"; then
            echo "simplestatefulfirewall: dispatcher script will brick network please remove simple-stateful-firewall-git" | sudo tee /dev/kmsg
	else
	    systemctl restart simplestatefulfirewall.service
	fi
	;;
    down)
	if ps -acx | grep -q "[s]shd"; then
            echo "simplestatefulfirewall: dispatcher script will brick network please remove simple-stateful-firewall-git" | sudo tee /dev/kmsg
	else
	    systemctl restart simplestatefulfirewall.service
	fi
	;;
esac
