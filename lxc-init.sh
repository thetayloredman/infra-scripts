# This script only supports guests using the dpkg package manager (Debian, Ubuntu, and most variants).
# Must be run as root.

ZABBIX_SERVER="10.0.1.115"

echo 'Acquire::http { Proxy "http://apt-cacher.char.internal:3142"; }' > /etc/apt/apt.conf.d/99proxy

#
# configure Zabbix repositories
#
tmp="$(mktemp -d /tmp/zabbix-install.XXXXXXXXX)"
pushd "$tmp"

osid=$(awk -F= '$1=="ID" { print $2 ;}' /etc/os-release)
osver=$(awk -F= '$1=="VERSION_ID" { print $2 ;}' /etc/os-release | sed "s/\"//g")
zid="$osid$osver"
wget -O ./zabbix.deb "https://repo.zabbix.com/zabbix/7.0/$osid/pool/main/z/zabbix-release/zabbix-release_latest_7.0+${zid}_all.deb"
dpkg --force-confnew -i ./zabbix.deb

# patch the created sources.list files to use apt-cacher HTTPS
sed -i 's|https://|http://HTTPS///|' /etc/apt/sources.list.d/zabbix*

popd
rm -r "$tmp"

#
# install the Zabbix agent
#
apt update
apt install zabbix-agent2 -y
# You may also want to install and configure specific plugins depending on your workload

#
# agent configuration
#
host="$(hostname)"
sed -i -e "s/Server=127.0.0.1/Server=$ZABBIX_SERVER/g" /etc/zabbix/zabbix_agent2.conf
sed -i -e "s/ServerActive=127.0.0.1/ServerActive=$ZABBIX_SERVER/g" /etc/zabbix/zabbix_agent2.conf
sed -i -e "s/Hostname=Zabbix server/Hostname=$host/g" /etc/zabbix/zabbix_agent2.conf


cat > /etc/zabbix/zabbix_agent2.d/90-ubuntu-updates.conf << EOF
UserParameter=apt_updates.package,apt-get upgrade -s | grep -c ^Inst
UserParameter=apt_updates.security,apt-get upgrade -s | grep ^Inst | grep -c security
UserParameter=dns.nameserver,awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf
UserParameter=dns.resolv,tr '\n' ' ' < /etc/resolv.conf
EOF
cat > /etc/cron.daily/update-apt-repos << EOF
#!/usr/bin/env sh
apt-get update -qq
EOF
chmod +x /etc/cron.daily/update-apt-repos


systemctl restart zabbix-agent2
systemctl enable zabbix-agent2
systemctl status zabbix-agent2

