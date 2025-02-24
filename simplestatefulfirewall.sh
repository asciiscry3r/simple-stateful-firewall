#!/usr/bin/env bash
# Sources:
# Copyright (C) Klimenko Maxim Sergievich 2022
# https://www.frozentux.net/iptables-tutorial/iptables-tutorial.html#PROTOCOLSTXT
# https://github.com/ukanth/afwall/wiki/CustomScripts#droidwall-only-examples
# https://wiki.archlinux.org/title/simple_stateful_firewall
# https://ipgeolocation.io/resources/bogon.html

function install_settingstosysctl {

    if [ -f /etc/sysctl.conf ]; then
	sysctl -p /etc/sysctl.conf
    elif [ -f /etc/sysctl.d/99-sysctl.conf ]; then
	sysctl -p /etc/sysctl.d/99-sysctl.conf
    fi

    interfaces=(`sudo  sysctl -a | grep accept_redirects | awk 'BEGIN{FS="."} {print $4}'`)

    for i in "${interfaces[@]}"; do
	sudo sysctl -w net.ipv4.conf."${i}".forwarding=0
	sudo sysctl -w net.ipv6.conf."${i}".forwarding=0
	sudo sysctl -w net.ipv4.conf."${i}".bc_forwarding=0
	sudo sysctl -w net.ipv6.conf."${i}".bc_forwarding=0

	sudo sysctl -w net.ipv4.conf."${i}".rp_filter=1
	sudo sysctl -w net.ipv4.conf."${i}".accept_redirects=0
	sudo sysctl -w net.ipv4.conf."${i}".secure_redirects=0
	sudo sysctl -w net.ipv4.conf."${i}".send_redirects=0
	sudo sysctl -w net.ipv4.conf."${i}".accept_source_route=0
	sudo sysctl -w net.ipv6.conf."${i}".accept_redirects=0
	sudo sysctl -w net.ipv6.conf."${i}".accept_source_route=0
	sudo sysctl -w net.ipv4.conf."${i}".bootp_relay=0
	sudo sysctl -w net.ipv4.conf."${i}".proxy_arp=0
	sudo sysctl -w net.ipv4.conf."${i}".arp_ignore=1
        sudo sysctl -w net.ipv4.conf."${i}".arp_announce=2
	sudo sysctl -w net.ipv4.conf."${i}".log_martians=1
	sudo sysctl -w net.ipv6.conf."${i}".autoconf=0
        sudo sysctl -w net.ipv6.conf."${i}".accept_ra=0
	sudo sysctl -w net.ipv6.conf."${i}".use_tempaddr=2
	sudo sysctl -w net.ipv6.conf."${i}".rpl_seg_enabled=0
	sudo sysctl -w net.ipv6.conf."${i}".disable_ipv6=1
	echo "simplestatefulfirewall: Applied sysctl settings for interface" | sudo tee /dev/kmsg
    done
}

if ps -acx | grep -q "[s]shd-session"; then
    exit 1
fi

modprobe br_netfilter

install_settingstosysctl

iptables -F
iptables -t raw -F
iptables -t nat -F
iptables -t mangle -F

iptables -X
iptables -t raw -X
iptables -t nat -X
iptables -t mangle -X

ip6tables -F
ip6tables -t raw -F
ip6tables -t nat -F
ip6tables -t mangle -F

ip6tables -X
ip6tables -t raw -X
ip6tables -t nat -X
ip6tables -t mangle -X

echo "simplestatefulfirewall: Deleted previous iptables settings" | sudo tee /dev/kmsg

#### IpV4

#iptables -N TCP
#iptables -N UDP
iptables -N LOG_AND_DROP
iptables -N LOG_AND_DROP_OUT
iptables -N LOG_AND_DROP_T
iptables -N LOG_AND_DROP_E
iptables -N LOG_AND_REJECT
iptables -N bad_tcp_packets
#iptables -N UDP_LOG_AND_REJECT
#iptables -N TCP_LOG_AND_REJECT

iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -P INPUT DROP

iptables -A LOG_AND_DROP -j LOG --log-prefix "Iptables: v4Deny: " --log-level 7
iptables -A LOG_AND_DROP -j DROP
iptables -A LOG_AND_REJECT -j LOG --log-prefix "Iptables: v4Reject: " --log-level 7
iptables -A LOG_AND_REJECT -j REJECT --reject-with icmp-proto-unreachable
#iptables -A UDP_LOG_AND_REJECT -j LOG --log-prefix "Iptables: UDP v4Reject: " --log-level 7
#iptables -A UDP_LOG_AND_REJECT -j REJECT --reject-with icmp-proto-unreachable
#iptables -A TCP_LOG_AND_REJECT -j LOG --log-prefix "Iptables: TCP v4Reject: " --log-level 7
#iptables -A TCP_LOG_AND_REJECT -j REJECT --reject-with tcp-reset
iptables -A LOG_AND_DROP_T -j LOG --log-prefix "Iptables: v4Deny Torrents: " --log-level 7
iptables -A LOG_AND_DROP_T -j DROP
iptables -A LOG_AND_DROP_E -j LOG --log-prefix "Iptables: v4Deny Exploits: " --log-level 7
iptables -A LOG_AND_DROP_E -j DROP
iptables -A LOG_AND_DROP_OUT -j LOG --log-prefix "Iptables: v4Deny Out: " --log-level 7
iptables -A LOG_AND_DROP_OUT -j DROP

# 10.0.0.0/8
BLOCKLIST="0.0.0.0/8,100.64.0.0/10,169.254.0.0/16,172.16.0.0/12,192.0.0.0/24,192.0.2.0/24,192.88.99.0/24,198.18.0.0/15,198.51.100.0/24,203.0.113.0/24,224.0.0.0/4,240.0.0.0/4"

# Copyright (C) 2001  Oskar Andreasson <bluefluxATkoffeinDOTnet>
iptables -A bad_tcp_packets -p tcp -m limit -m length --length 20 -j LOG \
--log-prefix "Iptables: Empty packets: "
iptables -A bad_tcp_packets -p tcp -m length --length 20 -j DROP
iptables -A bad_tcp_packets -p tcp --tcp-flags SYN,ACK SYN,ACK \
-m state --state NEW -j REJECT --reject-with tcp-reset
iptables -A bad_tcp_packets -p tcp  -m limit ! --syn -m state --state NEW -j LOG \
--log-prefix "Iptables: Drop new not syn: "
iptables -A bad_tcp_packets -p tcp ! --syn -m state --state NEW -j DROP

####
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -i lo -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -p icmp -s 0/0 --icmp-type 8 -j ACCEPT
iptables -A INPUT -p icmp -s 0/0 --icmp-type 11 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -m length --length 86:0xffff -j DROP
iptables -A INPUT -p icmp -j DROP

iptables -A INPUT ! -i lo -m string --algo bm --hex-string '|28 29 20 7B|' -j LOG_AND_DROP_E
iptables -A INPUT ! -i lo -m string --algo bm --hex-string '|FF FF FF FF FF FF|' -j LOG_AND_DROP_E
iptables -A INPUT ! -i lo -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_DROP_E
iptables -A INPUT ! -i lo -m string --algo bm --hex-string '|72 70 63 6E 65 74 70 2E 65 78 65 00 72 70 63 6E 65 74 70 00|' -j LOG_AND_DROP_E

iptables -A INPUT -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_DROP_E
iptables -A INPUT -m u32 --u32 "8&0xFFF=0x4d5a" -j LOG_AND_DROP_E
iptables -A INPUT -p tcp \
  -m connbytes --connbytes 0:1024 \
    --connbytes-dir both --connbytes-mode bytes \
  -m state --state ESTABLISHED \
  -m u32 --u32 "0>>22&0x3C@ 12>>26&0x3C@ 0=0x52464220" \
  -m string --algo kmp --string "RFB 003." --to 130 \
  -j REJECT --reject-with tcp-reset

iptables -A INPUT -f -j LOG_AND_REJECT
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j LOG_AND_REJECT
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j LOG_AND_REJECT
iptables -A INPUT -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/second --limit-burst 2 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate INVALID -j LOG_AND_REJECT
#iptables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
iptables -A INPUT -p tcp -j bad_tcp_packets
iptables -A INPUT -p tcp -m recent --set --rsource --name TCP-PORTSCAN -j REJECT --reject-with tcp-reset
iptables -A INPUT -p udp -m recent --set --rsource --name UDP-PORTSCAN -j REJECT --reject-with icmp-port-unreachable
#iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP
iptables -A INPUT -s ${BLOCKLIST} -j LOG_AND_DROP
#iptables -A UDP -p udp -j UDP_LOG_AND_REJECT
#iptables -A TCP -p tcp -j TCP_LOG_AND_REJECT


iptables -t raw -A PREROUTING -m rpfilter --invert -j DROP
iptables -t raw -A PREROUTING -m length --length 8 -j DROP
iptables -A INPUT -j LOG_AND_REJECT

iptables -A OUTPUT -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o lo -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT

iptables -A OUTPUT ! -o lo -m string --algo bm --hex-string '|28 29 20 7B|' -j LOG_AND_DROP_E
iptables -A OUTPUT ! -o lo -m string --algo bm --hex-string '|FF FF FF FF FF FF|' -j LOG_AND_DROP_E
iptables -A OUTPUT ! -o lo -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_DROP_E
iptables -A OUTPUT ! -o lo -m string --algo bm --hex-string '|72 70 63 6E 65 74 70 2E 65 78 65 00 72 70 63 6E 65 74 70 00|' -j LOG_AND_DROP_E
iptables -A OUTPUT -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_DROP_E

iptables -A OUTPUT -m u32 --u32 "8&0xFFF=0x4d5a" -j LOG_AND_DROP_E
iptables -A OUTPUT -p dccp -j LOG_AND_DROP_OUT
iptables -A OUTPUT -p sctp -j LOG_AND_DROP_OUT
iptables -A OUTPUT -f -j LOG_AND_DROP_OUT
iptables -A OUTPUT -p tcp -j bad_tcp_packets
iptables -A OUTPUT -s ${BLOCKLIST} -j LOG_AND_DROP_OUT
iptables -A OUTPUT -m string --algo bm --string “BitTorrent” -j LOG_AND_DROP_T
iptables -A OUTPUT -m limit --limit 3/minute --limit-burst 3 -j LOG --log-prefix "Iptables: IPT OUTPUT packet died: "

iptables -A OUTPUT -o lo -j LOG_AND_DROP_OUT
iptables -A OUTPUT -j LOG_AND_DROP_OUT

echo "simplestatefulfirewall: Applied IPV4 rules" | sudo tee /dev/kmsg

#### IpV6

#ip6tables -N TCP
#ip6tables -N UDP
ip6tables -N LOG_AND_DROP
ip6tables -N LOG_AND_DROP_OUT
ip6tables -N LOG_AND_REJECT
ip6tables -N bad_tcp_packets
ip6tables -N icmp_packets

ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT
ip6tables -P INPUT DROP

ip6tables -A LOG_AND_DROP -j LOG --log-prefix "Iptables: v6Deny: " --log-level 7
ip6tables -A LOG_AND_DROP -j DROP
ip6tables -A LOG_AND_DROP_OUT -j LOG --log-prefix "Iptables: v6Deny: " --log-level 7
ip6tables -A LOG_AND_DROP_OUT -j DROP
ip6tables -A LOG_AND_REJECT -j LOG --log-prefix "Iptables: v6Reject: " --log-level 7
ip6tables -A LOG_AND_REJECT -j REJECT --reject-with icmp6-adm-prohibited

V6BLOCKLIST="::/128,::1/128,::ffff:0:0/96,::/96,100::/64,2001:10::/28,2001:10::/28,2001:db8::/32,fc00::/7,fe80::/128,fec0::/10,2600:1901:0:8813::/128,2002::/24,2002:a00::/24,2002:a00::/24,2002:a9fe::/24,2002:ac10::/28,2002:c000::/40,2002:c000:200::/40,2002:c0a8::/32,2002:c612::/31,2002:c633:6400::/40,2002:cb00:7100::/40,2002:e000::/20,2002:f000::/20,2002:ffff:ffff::/48,2001::/40,2001:0:a00::/40,2001:0:7f00::/40,2001:0:c000::/56,2001:0:ac10::/44,2001:0:a9fe::/48,2001:0:c000:200::/56,2001:0:c0a8::/48,2001:0:c612::/47,2001:0:c633:6400::/56,2001:0:cb00:7100::/56,2001:0:e000::/36,2001:0:f000::/36"

# Copyright (C) 2001  Oskar Andreasson <bluefluxATkoffeinDOTnet>
ip6tables -A bad_tcp_packets -p tcp  -m limit -m length --length 20 -j LOG \
--log-prefix "Iptables: Empty packets: "
ip6tables -A bad_tcp_packets -p tcp -m length --length 20 -j DROP
ip6tables -A bad_tcp_packets -p tcp --tcp-flags SYN,ACK SYN,ACK \
-m state --state NEW -j REJECT --reject-with tcp-reset
ip6tables -A bad_tcp_packets -p tcp  -m limit ! --syn -m state --state NEW -j LOG \
--log-prefix "Iptables: Drop new not syn: "
ip6tables -A bad_tcp_packets -p tcp ! --syn -m state --state NEW -j DROP

####
ip6tables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip6tables -A INPUT -i lo -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT

ip6tables -A icmp_packets -p ipv6-icmp -s 0/0 --icmpv6-type 8 -j ACCEPT
ip6tables -A icmp_packets -p ipv6-icmp -s 0/0 --icmpv6-type 11 -j ACCEPT
ip6tables -A icmp_packets -p ipv6-icmp --icmpv6-type echo-request -m length --length 86:0xffff -j DROP
ip6tables -A INPUT -p icmp -j DROP
ip6tables -A INPUT -m string --algo bm --hex-string '|28 29 20 7B|' -j LOG_AND_REJECT
ip6tables -A INPUT -m string --algo bm --hex-string '|FF FF FF FF FF FF|' -j LOG_AND_REJECT
ip6tables -A INPUT -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_REJECT
ip6tables -A INPUT -m string --algo bm --hex-string '|72 70 63 6E 65 74 70 2E 65 78 65 00 72 70 63 6E 65 74 70 00|' -j LOG_AND_REJECT
ip6tables -A INPUT -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_REJECT
ip6tables -A INPUT -m u32 --u32 "8&0xFFF=0x4d5a" -j LOG_AND_DROP
ip6tables -A INPUT -p tcp \
  -m connbytes --connbytes 0:1024 \
    --connbytes-dir both --connbytes-mode bytes \
  -m state --state ESTABLISHED \
  -m u32 --u32 "0>>22&0x3C@ 12>>26&0x3C@ 0=0x52464220" \
  -m string --algo kmp --string "RFB 003." --to 130 \
  -j REJECT --reject-with tcp-reset
ip6tables -A INPUT -m ipv6header --header frag --soft -j LOG_AND_REJECT
ip6tables -A INPUT -p tcp --tcp-flags ALL ALL -j LOG_AND_REJECT
ip6tables -A INPUT -p tcp --tcp-flags ALL NONE -j LOG_AND_REJECT
ip6tables -A INPUT -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/second --limit-burst 2 -j ACCEPT
ip6tables -A INPUT -m conntrack --ctstate INVALID -j LOG_AND_REJECT
#ip6tables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
ip6tables -A INPUT -p tcp -j bad_tcp_packets
ip6tables -A INPUT -p tcp -m recent --set --rsource --name TCP-PORTSCAN -j REJECT --reject-with tcp-reset
ip6tables -A INPUT -p udp -m recent --set --rsource --name UDP-PORTSCAN -j REJECT --reject-with icmp6-adm-prohibited
#ip6tables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP
ip6tables -A INPUT -s ${V6BLOCKLIST} -j LOG_AND_REJECT
#ip6tables -A UDP -p udp -j LOG_AND_REJECT
#ip6tables -A TCP -p tcp -j LOG_AND_REJECT
ip6tables -A INPUT -j LOG_AND_REJECT

ip6tables -A OUTPUT -o lo -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j ACCEPT

ip6tables -A OUTPUT -m string --algo bm --hex-string '|28 29 20 7B|' -j LOG_AND_DROP
ip6tables -A OUTPUT -m string --algo bm --hex-string '|FF FF FF FF FF FF|' -j LOG_AND_DROP
ip6tables -A OUTPUT -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_DROP
ip6tables -A OUTPUT -m string --algo bm --hex-string '|72 70 63 6E 65 74 70 2E 65 78 65 00 72 70 63 6E 65 74 70 00|' -j LOG_AND_DROP
ip6tables -A OUTPUT -m string --algo bm --hex-string '|D1 E0 F5 8B 4D 0C 83 D1 00 8B EC FF 33 83 C3 04|' -j LOG_AND_DROP
ip6tables -A OUTPUT -m u32 --u32 "8&0xFFF=0x4d5a" -j LOG_AND_DROP_OUT
ip6tables -A OUTPUT -s ${V6BLOCKLIST} -j LOG_AND_DROP_OUT
ip6tables -A OUTPUT -p tcp -j bad_tcp_packets
ip6tables -A OUTPUT -m ipv6header --header frag --soft -j LOG_AND_DROP_OUT
ip6tables -A OUTPUT -m string --algo bm --string “BitTorrent” -j LOG_AND_DROP_OUT
ip6tables -A OUTPUT -s ::1/32 -p ICMP -m limit -j LOG_AND_DROP_OUT
ip6tables -A OUTPUT -s ::1/32 -p UDP -m limit --sport 53 -j LOG_AND_DROP_OUT
ip6tables -A OUTPUT -s ::1/32 -p TCP -m limit --sport 53 -j LOG_AND_DROP_OUT
ip6tables -A OUTPUT -m limit --limit 3/minute --limit-burst 3 -j LOG --log-prefix "Iptables: IPT OUTPUT packet died: "

ip6tables -A OUTPUT -j LOG_AND_DROP_OUT

ip6tables -t raw -A PREROUTING -m rpfilter --invert -j DROP
ip6tables -t raw -A PREROUTING -m length --length 8 -j DROP

echo "simplestatefulfirewall: Applied IPV6 rules" | sudo tee /dev/kmsg

#### Mangle

iptables -t mangle -A PREROUTING -m rpfilter --invert -j DROP
iptables -t mangle -A PREROUTING -m length --length 8 -j DROP
iptables -t mangle -A PREROUTING -j ACCEPT

ip6tables -t mangle -A PREROUTING -m rpfilter --invert -j DROP
ip6tables -t mangle -A PREROUTING -m length --length 8 -j DROP
ip6tables -t mangle -A PREROUTING -j ACCEPT

echo "simplestatefulfirewall: Applied Mangle rules" | sudo tee /dev/kmsg


release=`grep -e '^ID=' /etc/os-release |  cut -c 4-`

if [[ $release == 'arch' ]]; then

    iptables-save > /etc/iptables/iptables.rules
    ip6tables-save > /etc/iptables/ip6tables.rules

    systemctl enable iptables
    systemctl start iptables
    systemctl restart iptables

    systemctl enable ip6tables
    systemctl start ip6tables
    systemctl restart ip6tables

    echo "simplestatefulfirewall: Rules saved and iptables service is enabled" | sudo tee /dev/kmsg

    if [ -f /usr/lib/systemd/system/opensnitchd.service ]; then
        systemctl restart opensnitchd
	echo "simplestatefulfirewall: Restarted opensnitch for recreating his iptables rules" | sudo tee /dev/kmsg
    fi
elif [[ $release == 'manjaro' ]]; then
    iptables-save > /etc/iptables/iptables.rules
    ip6tables-save > /etc/iptables/ip6tables.rules

    if [ -f /usr/lib/systemd/system/ufw.service ]; then
        systemctl disable ufw
        systemctl stop ufw
    fi

    systemctl enable iptables
    systemctl start iptables
    systemctl restart iptables

    systemctl enable ip6tables
    systemctl start ip6tables
    systemctl restart ip6tables

    echo "simplestatefulfirewall: Rules saved and iptables service is enabled" | sudo tee /dev/kmsg

    if [ -f /usr/lib/systemd/system/opensnitchd.service ]; then
	systemctl restart opensnitchd
	echo "simplestatefulfirewall: Restarted opensnitch for recreating his iptables rules" | sudo tee /dev/kmsg
    fi
elif [[ $release == 'raspbian' ]]; then
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v4

    if [ -f /usr/lib/systemd/system/ufw.service ]; then
        systemctl disable ufw
        systemctl stop ufw
    fi

    systemctl enable netfilter-persistent
    systemctl start netfilter-persistent
    systemctl restart netfilter-persistent

    echo "simplestatefulfirewall: Rules saved and iptables service is enabled" | sudo tee /dev/kmsg

    if [ -f /usr/lib/systemd/system/opensnitchd.service ]; then
        systemctl restart opensnitch
	echo "simplestatefulfirewall: Restarted opensnitch for recreating his iptables rules" | sudo tee /dev/kmsg
    fi
elif [[ $release == 'ubuntu' ]]; then

    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v4

    if [ -f /usr/lib/systemd/system/ufw.service ]; then
        systemctl disable ufw
        systemctl stop ufw
    fi

    systemctl enable netfilter-persistent
    systemctl start netfilter-persistent
    systemctl restart netfilter-persistent

    echo "simplestatefulfirewall: Rules saved and iptables service is enabled" | sudo tee /dev/kmsg

    if [ -f /usr/lib/systemd/system/opensnitchd.service ]; then
        systemctl restart opensnitch
	echo "simplestatefulfirewall: Restarted opensnitch for recreating his iptables rules" | sudo tee /dev/kmsg
    fi
fi

#sudo -u DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus notify-send "Simple statefull firewall is restarted or started"
