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

![Firewall](https://i.ibb.co/8DLD6g97/img-2025-02-24-185427.png)
