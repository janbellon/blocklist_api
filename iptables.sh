ipset create blocklist hash:ip maxelem 100000
ipset create blocklist_networks hash:net maxelem 100000

iptables -I INPUT -m set --match-set blocklist src -j DROP
iptables -I INPUT -m set --match-set blocklist_networks src -j DROP
