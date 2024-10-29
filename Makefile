bindir = /usr/bin/
libdir = /usr/lib/
confdir = /etc/

.PHONY: install
install:
	mkdir -p ${DESTDIR}${confdir}systemd/system/NetworkManager-dispatcher.service.d/
	chmod 0750 -R ${DESTDIR}${confdir}systemd/system/NetworkManager-dispatcher.service.d/
	install -Dm0750 simplestatefulfirewall.install ${DESTDIR}${confdir}simplestatefulfirewall/simplestatefulfirewall.install
	install -Dm0640 simplestatefulfirewall.service ${DESTDIR}${libdir}systemd/system/simplestatefulfirewall.service
	install -Dm0640 simplestatefulfirewall.timer ${DESTDIR}${libdir}systemd/system/simplestatefulfirewall.timer
	install -Dm0750 simplestatefulfirewall.sh ${DESTDIR}${bindir}simplestatefulfirewall.sh
	install -Dm0640 remain_after_exit.conf ${DESTDIR}${confdir}systemd/system/NetworkManager-dispatcher.service.d/remain_after_exit.conf
	install -Dm0750 30-restart-firewall.sh ${DESTDIR}${confdir}NetworkManager/dispatcher.d/30-restart-firewall.sh
	install -Dm0640 sysctl.conf ${DESTDIR}${confdir}sysctl.d/00-sysctl.conf

.PHONY: uninstall
uninstall:
	rm -f ${DESTDIR}${libdir}systemd/system/simplestatefulfirewall.service
	rm -f ${DESTDIR}${libdir}systemd/system/simplestatefulfirewall.timer
	rm -f ${DESTDIR}${bindir}simplestatefulfirewall.sh
	rm -f ${DESTDIR}${confdir}systemd/system/NetworkManager-dispatcher.service.d/remain_after_exit.conf
	rm -f ${DESTDIR}${confdir}NetworkManager/dispatcher.d/30-restart-firewall.sh
	rm -f ${DESTDIR}${confdir}sysctl.d/00-sysctl.conf
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

.PHONY: clean
clean:
	rm -r $(DESTDIR)

