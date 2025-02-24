# Simple Stateful Firewall
Packet filtering for self defence

Disable ufw or other preinstalled firewall
```
sudo systemctl stop $firewallname.service
sudo systemctl disable $firewallname.service
```

Or script disable some of them for you

And start

```
sudo bash INSTALL.sh
```

If you use Opensnitch, as web application firewall, then delete all rules in "System rules" tab.

![LOG](https://i.imgur.com/q9KgJjH.png)
