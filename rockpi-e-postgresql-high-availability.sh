#!/bin/bash

INFO_COLOR="\033[0;32m"
ERROR_COLOR="\033[0;31m"
COLOR_END="\033[0m"

if [ -z "$1" ]; then
    echo -e "${ERROR_COLOR}-> 請輸入設備編號<1-3>, ex:./systemBulid.sh <1-3> <p,r>${COLOR_END}"
    exit 1
fi

DEVICE_NUMBER=$1

echo -e "${INFO_COLOR}-> 刪除 rock 帳號${COLOR_END}"
usermod -L rock
rm -rf /home/rock
userdel rock

echo -e "${INFO_COLOR}-> 更新apt${COLOR_END}"
apt update -y && apt upgrade -y
apt install -y wget
export DISTRO=focal-stable
wget -O - apt.radxa.com/$DISTRO/public.key | sudo apt-key add -
apt install -y zsh git htop iftop curl unzip nano rsync iptables linux-cpupower locales
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

RC_LOCAL="/etc/rc.local"
HOSTNAME="psql-${DEVICE_NUMBER}"
echo -e "${INFO_COLOR}-> 設定 rc.local${COLOR_END}"
echo "#!/bin/sh -e" | tee ${RC_LOCAL}
echo "" | tee -a ${RC_LOCAL}
echo "HOSTNAME=\"${HOSTNAME}\"" | tee -a ${RC_LOCAL}
echo "echo \"\$HOSTNAME\" > \"/etc/hostname\"" | tee -a ${RC_LOCAL}
echo "CURRENT_HOSTNAME=\$(cat /proc/sys/kernel/hostname)" | tee -a ${RC_LOCAL}
echo "sed -i \"s/127.0.0.1.*/127.0.0.1\tlocalhost \$HOSTNAME/g\" /etc/hosts" | tee -a ${RC_LOCAL}
echo "/bin/hostname \$HOSTNAME" | tee -a ${RC_LOCAL}
echo "" | tee -a ${RC_LOCAL}
echo "exit 0" | tee -a ${RC_LOCAL}
chmod u+x ${RC_LOCAL}

DHCPCD_CONF="/etc/dhcpcd.conf"

if [ "$DEVICE_NUMBER" -eq 2 ]; then
    ETH0_IP_ADDRESS="192.168.2.54"
    ETH1_IP_ADDRESS="192.168.168.154"
elif [ "$DEVICE_NUMBER" -eq 3 ]; then
    ETH0_IP_ADDRESS="192.168.2.55"
    ETH1_IP_ADDRESS="192.168.168.155"
else
    ETH0_IP_ADDRESS="192.168.2.53"
    ETH1_IP_ADDRESS="192.168.168.153"
fi

ETH0_ROUTERS="192.168.2.254"
ETH1_ROUTERS="192.168.168.254"
echo -e "${INFO_COLOR}-> 設定固定網路${COLOR_END}"
echo "allowinterfaces eth0 eth1" | tee ${DHCPCD_CONF}
echo "" | tee -a ${DHCPCD_CONF}
echo "noipv6rs" | tee -a ${DHCPCD_CONF}
echo "hostname" | tee -a ${DHCPCD_CONF}
echo "clientid" | tee -a ${DHCPCD_CONF}
echo "persistent" | tee -a ${DHCPCD_CONF}
echo "option rapid_commit" | tee -a ${DHCPCD_CONF}
echo "option domain_name_servers, domain_name, domain_search, host_name" | tee -a ${DHCPCD_CONF}
echo "option classless_static_routes" | tee -a ${DHCPCD_CONF}
echo "require dhcp_server_identifier" | tee -a ${DHCPCD_CONF}
echo "slaac private" | tee -a ${DHCPCD_CONF}
echo "nohook lookup-hostname" | tee -a ${DHCPCD_CONF}
echo "noarp" | tee -a ${DHCPCD_CONF}
echo "" | tee -a ${DHCPCD_CONF}
echo "interface eth0" | tee -a ${DHCPCD_CONF}
echo "static ip_address=${ETH0_IP_ADDRESS}/24" | tee -a ${DHCPCD_CONF}
echo "static routers=${ETH0_ROUTERS}" | tee -a ${DHCPCD_CONF}
echo "metric 202" | tee -a ${DHCPCD_CONF}
echo "" | tee -a ${DHCPCD_CONF}
echo "interface eth1" | tee -a ${DHCPCD_CONF}
echo "static ip_address=${ETH1_IP_ADDRESS}/24" | tee -a ${DHCPCD_CONF}
echo "static routers=${ETH1_ROUTERS}" | tee -a ${DHCPCD_CONF}
echo "metric 203" | tee -a ${DHCPCD_CONF}

TIMEZONE="Asia/Taipei"
TIMESYNCD="/etc/systemd/timesyncd.conf"
echo -e "${INFO_COLOR}-> 設定時區 ${TIMEZONE} 並開啟自動校時${COLOR_END}"
systemctl stop ntp
apt purge -y ntp
timedatectl set-timezone ${TIMEZONE}
sed -i 's/#NTP=/NTP=time.stdtime.gov.tw/' ${TIMESYNCD}
sed -i 's/#PollIntervalMinSec=32/PollIntervalMinSec=32/' ${TIMESYNCD}
sed -i 's/#PollIntervalMaxSec=2048/PollIntervalMaxSec=300/' ${TIMESYNCD}
timedatectl set-ntp yes
systemctl daemon-reload
systemctl restart systemd-timesyncd

FSTAB="/etc/fstab"
echo -e "${INFO_COLOR}-> 設定 1G虛擬記憶體${COLOR_END}"
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile    none    swap    sw    0    0" | tee -a ${FSTAB}

SYSCTL_CONFIG="/etc/sysctl.conf"
echo -e "${INFO_COLOR}-> 系統調教${COLOR_END}"
cpupower frequency-set -g performance
echo "kernel.printk = 3 3 3 3" | tee -a ${SYSCTL_CONFIG}
echo "fs.inotify.max_user_watches = 524288" | tee -a ${SYSCTL_CONFIG}
echo "net.core.rmem_max = 25165824" | tee -a ${SYSCTL_CONFIG}
echo "net.core.rmem_default = 8388608" | tee -a ${SYSCTL_CONFIG}
echo "net.core.netdev_max_backlog = 65536" | tee -a ${SYSCTL_CONFIG}
echo "net.core.somaxconn = 2048" | tee -a ${SYSCTL_CONFIG}
echo "net.core.optmem_max = 81920" | tee -a ${SYSCTL_CONFIG}
echo "net.ipv4.route.flush = 1" | tee -a ${SYSCTL_CONFIG}
echo "net.ipv4.udp_mem = 192576 256768 385152" | tee -a ${SYSCTL_CONFIG}
echo "net.ipv4.udp_rmem_min = 16384" | tee -a ${SYSCTL_CONFIG}
echo "net.ipv4.igmp_max_msf = 256" | tee -a ${SYSCTL_CONFIG}
echo "net.ipv4.conf.eth0.force_igmp_version = 2" | tee -a ${SYSCTL_CONFIG}
echo "vm.swappiness = 10" | tee -a ${SYSCTL_CONFIG}
echo "vm.vfs_cache_pressure = 50" | tee -a ${SYSCTL_CONFIG}
echo "vm.dirty_ratio = 60" | tee -a ${SYSCTL_CONFIG}
echo "vm.dirty_background_ratio = 2" | tee -a ${SYSCTL_CONFIG}
echo "vm.min_free_kbytes = 16184" | tee -a ${SYSCTL_CONFIG}

ZSHRC="/root/.zshrc"
echo -e "${INFO_COLOR}-> 安裝 oh-my-zsh${COLOR_END}"
echo "1234" | chsh -s /bin/zsh root
echo n | sh -c "$(curl -fksSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="sonicradish"\nDISABLE_AUTO_UPDATE="true"/' ${ZSHRC}

LOCAL_GEN="/etc/locale.gen"
echo -e "${INFO_COLOR}-> 處理文字編輯器亂碼問題${COLOR_END}"
sed -i 's/# zh_TW.UTF-8 UTF-8/zh_TW.UTF-8 UTF-8/' ${LOCAL_GEN}
locale-gen
update-locale LANG=zh_TW.UTF-8

PG_CONF="/etc/postgresql/16/main/postgresql.conf"
PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
PG_DATA="/var/lib/postgresql/16/main"
echo -e "${INFO_COLOR}-> 安裝 postgresql 16 服務${COLOR_END}"
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
apt update
apt -y install postgresql-16
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
sed -i 's/#listen_addresses = '\''localhost'\''/listen_addresses = '\''*'\''/' ${PG_CONF}
echo "host    all             postgres        192.168.2.0/24          scram-sha-256" | tee -a ${PG_HBA}
echo "host    replication     postgres        192.168.2.53/32         scram-sha-256" | tee -a ${PG_HBA}
echo "host    replication     postgres        192.168.2.54/32         scram-sha-256" | tee -a ${PG_HBA}
echo "host    replication     postgres        192.168.2.55/32         scram-sha-256" | tee -a ${PG_HBA}
/etc/init.d/postgresql stop
rm -rf ${PG_DATA}

ETCD_SERVICE="/usr/lib/systemd/system/etcd.service"
echo -e "${INFO_COLOR}-> 安裝 ETCD 服務${COLOR_END}"
mkdir -p /etc/etcd
wget https://github.com/etcd-io/etcd/releases/download/v3.5.13/etcd-v3.5.13-linux-arm64.tar.gz
tar -zxf etcd-v3.5.13-linux-arm64.tar.gz
cp etcd-v3.5.13-linux-arm64/etcd* /usr/local/bin
rm -rf etcd-v3.5.13-linux-arm64 etcd-v3.5.13-linux-arm64.tar.gz
echo "[Unit]" | tee ${ETCD_SERVICE}
echo "Description=etcd key-value store" | tee -a ${ETCD_SERVICE}
echo "Documentation=https://etcd.io/docs/" | tee -a ${ETCD_SERVICE}
echo "After=network.target" | tee -a ${ETCD_SERVICE}
echo "" | tee -a ${ETCD_SERVICE}
echo "[Service]" | tee -a ${ETCD_SERVICE}
echo "Type=notify" | tee -a ${ETCD_SERVICE}
echo "ExecStart=/usr/local/bin/etcd \\" | tee -a ${ETCD_SERVICE}
echo "  --name etcd${DEVICE_NUMBER} \\" | tee -a ${ETCD_SERVICE}
echo "  --data-dir /etc/etcd \\" | tee -a ${ETCD_SERVICE}
echo "  --advertise-client-urls http://${ETH0_IP_ADDRESS}:2379 \\" | tee -a ${ETCD_SERVICE}
echo "  --initial-advertise-peer-urls http://${ETH0_IP_ADDRESS}:2380 \\" | tee -a ${ETCD_SERVICE}
echo "  --initial-cluster etcd1=http://192.168.2.53:2380,etcd2=http://192.168.2.54:2380,etcd3=http://192.168.2.55:2380 \\" | tee -a ${ETCD_SERVICE}
echo "  --listen-client-urls http://0.0.0.0:2379 \\" | tee -a ${ETCD_SERVICE}
echo "  --listen-peer-urls http://0.0.0.0:2380 \\" | tee -a ${ETCD_SERVICE}
echo "  --initial-cluster-token postgresql-cluster \\" | tee -a ${ETCD_SERVICE}
echo "  --initial-cluster-state new \\" | tee -a ${ETCD_SERVICE}
echo "  --enable-v2=true \\" | tee -a ${ETCD_SERVICE}
echo "  --log-level info \\" | tee -a ${ETCD_SERVICE}
echo "  --logger zap \\" | tee -a ${ETCD_SERVICE}
echo "  --log-outputs stderr" | tee -a ${ETCD_SERVICE}
echo "Restart=on-failure" | tee -a ${ETCD_SERVICE}
echo "RestartSec=5" | tee -a ${ETCD_SERVICE}
echo "LimitNOFILE=40000" | tee -a ${ETCD_SERVICE}
echo "" | tee -a ${ETCD_SERVICE}
echo "[Install]" | tee -a ${ETCD_SERVICE}
echo "WantedBy=multi-user.target" | tee -a ${ETCD_SERVICE}
echo "" | tee -a ${ETCD_SERVICE}
systemctl daemon-reload
systemctl enable etcd

PATRONI_YML="/etc/patroni/patroni.yml"
PATRONI_SERVICE="/etc/systemd/system/patroni.service"
echo -e "${INFO_COLOR}-> 安裝 patroni 服務${COLOR_END}"
mkdir -p /etc/patroni
apt install -y python3-pip python3-psycopg2
wget https://bootstrap.pypa.io/get-pip.py
python3.7 get-pip.py
rm get-pip.py
pip install --upgrade pip
pip install --upgrade setuptools
pip install 'patroni[all]'
echo "scope: postgresql-cluster" | tee ${PATRONI_YML}
echo "namespace: /service/" | tee -a ${PATRONI_YML}
echo "name: ${HOSTNAME}" | tee -a ${PATRONI_YML}
echo "" | tee -a ${PATRONI_YML}
echo "restapi:" | tee -a ${PATRONI_YML}
echo "  listen: 0.0.0.0:8008" | tee -a ${PATRONI_YML}
echo "  connect_address: ${ETH0_IP_ADDRESS}:8008" | tee -a ${PATRONI_YML}
echo "" | tee -a ${PATRONI_YML}
echo "etcd:" | tee -a ${PATRONI_YML}
echo "  hosts:" | tee -a ${PATRONI_YML}
echo "  - 192.168.2.53:2379" | tee -a ${PATRONI_YML}
echo "  - 192.168.2.54:2379" | tee -a ${PATRONI_YML}
echo "  - 192.168.2.55:2379" | tee -a ${PATRONI_YML}
echo "" | tee -a ${PATRONI_YML}
echo "bootstrap:" | tee -a ${PATRONI_YML}
echo "  dcs:" | tee -a ${PATRONI_YML}
echo "    ttl: 30" | tee -a ${PATRONI_YML}
echo "    loop_wait: 10" | tee -a ${PATRONI_YML}
echo "    retry_timeout: 10" | tee -a ${PATRONI_YML}
echo "    maximum_lag_on_failover: 1048576" | tee -a ${PATRONI_YML}
echo "    postgresql:" | tee -a ${PATRONI_YML}
echo "      use_pg_rewind: true" | tee -a ${PATRONI_YML}
echo "      use_slots: true" | tee -a ${PATRONI_YML}
echo "" | tee -a ${PATRONI_YML}
echo "  initdb:" | tee -a ${PATRONI_YML}
echo "  - encoding: UTF8" | tee -a ${PATRONI_YML}
echo "  - data-checksums" | tee -a ${PATRONI_YML}
echo "" | tee -a ${PATRONI_YML}
echo "  pg_hba:" | tee -a ${PATRONI_YML}
echo "  - host all postgres 192.168.2.0/24 scram-sha-256" | tee -a ${PATRONI_YML}
echo "" | tee -a ${PATRONI_YML}
echo "postgresql:" | tee -a ${PATRONI_YML}
echo "  listen: 0.0.0.0:5432" | tee -a ${PATRONI_YML}
echo "  connect_address: ${ETH0_IP_ADDRESS}:5432" | tee -a ${PATRONI_YML}
echo "  data_dir: /var/lib/postgresql/16/main" | tee -a ${PATRONI_YML}
echo "  config_dir: /etc/postgresql/16/main" | tee -a ${PATRONI_YML}
echo "  authentication:" | tee -a ${PATRONI_YML}
echo "    replication:" | tee -a ${PATRONI_YML}
echo "      username: postgres" | tee -a ${PATRONI_YML}
echo "      password: postgres" | tee -a ${PATRONI_YML}
echo "    superuser:" | tee -a ${PATRONI_YML}
echo "      username: postgres" | tee -a ${PATRONI_YML}
echo "      password: postgres" | tee -a ${PATRONI_YML}
echo "  parameters:" | tee -a ${PATRONI_YML}
echo "    unix_socket_directories: '/var/run/postgresql'" | tee -a ${PATRONI_YML}
echo "    wal_level: replica" | tee -a ${PATRONI_YML}
echo "    hot_standby: "on"" | tee -a ${PATRONI_YML}
echo "    wal_keep_segments: 8" | tee -a ${PATRONI_YML}
echo "    max_wal_senders: 10" | tee -a ${PATRONI_YML}
echo "    max_replication_slots: 10" | tee -a ${PATRONI_YML}
echo "    archive_mode: "on"" | tee -a ${PATRONI_YML}
echo "    archive_command: 'cp %p /var/lib/postgresql/wal_archive/%f'" | tee -a ${PATRONI_YML}
echo "" | tee -a ${PATRONI_YML}

echo "[Unit]" | tee ${PATRONI_SERVICE}
echo "Description=Patroni PostgreSQL Cluster Manager" | tee -a ${PATRONI_SERVICE}
echo "After=network.target" | tee -a ${PATRONI_SERVICE}
echo "" | tee -a ${PATRONI_SERVICE}
echo "[Service]" | tee -a ${PATRONI_SERVICE}
echo "Environment=\"PATH=/usr/lib/postgresql/16/bin:\$PATH\"" | tee -a ${PATRONI_SERVICE}
echo "Type=simple" | tee -a ${PATRONI_SERVICE}
echo "User=postgres" | tee -a ${PATRONI_SERVICE}
echo "Group=postgres" | tee -a ${PATRONI_SERVICE}
echo "ExecStart=/usr/local/bin/patroni ${PATRONI_YML}" | tee -a ${PATRONI_SERVICE}
echo "Restart=on-failure" | tee -a ${PATRONI_SERVICE}
echo "" | tee -a ${PATRONI_SERVICE}
echo "[Install]" | tee -a ${PATRONI_SERVICE}
echo "WantedBy=multi-user.target" | tee -a ${PATRONI_SERVICE}
echo "" | tee -a ${PATRONI_SERVICE}
systemctl daemon-reload
systemctl enable patroni

PGBOUNCER_INI="/etc/pgbouncer/pgbouncer.ini"
PGBOUNCER_USERLIST="/etc/pgbouncer/userlist.txt"
echo -e "${INFO_COLOR}-> 安裝 pgbouncer 服務${COLOR_END}"
apt install -y pgbouncer
sed -i 's/\[databases\]/\[databases\]\npostgres = host=localhost port=5432 dbname=postgres/' ${PGBOUNCER_INI}
sed -i 's/listen_addr = localhost/listen_addr = */' ${PGBOUNCER_INI}
sed -i 's/;pool_mode = session/pool_mode = session/' ${PGBOUNCER_INI}
sed -i 's/;max_client_conn = 100/max_client_conn = 100/' ${PGBOUNCER_INI}
sed -i 's/;default_pool_size = 20/default_pool_size = 20/' ${PGBOUNCER_INI}
sed -i 's/;log_connections = 1/log_connections = 1/' ${PGBOUNCER_INI}
sed -i 's/;log_disconnections = 1/log_disconnections = 1/' ${PGBOUNCER_INI}
echo "\"postgres\" \"postgres\"" | tee ${PGBOUNCER_USERLIST}
systemctl restart pgbouncer
systemctl enable pgbouncer


HAPROXY_ACCOUNT="admin"
HAPROXY_PASSWORD="admin"
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
echo -e "${INFO_COLOR}-> 安裝 HAProxy 服務${COLOR_END}"
curl https://haproxy.debian.net/bernat.debian.org.gpg \
      | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg
echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" \
      http://haproxy.debian.net buster-backports-2.6 main \
      > /etc/apt/sources.list.d/haproxy.list

apt update -y
apt install -y haproxy=2.6.\*
echo "global" | tee ${HAPROXY_CONFIG}
echo "    daemon" | tee -a ${HAPROXY_CONFIG}
echo "    maxconn 256" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "    ca-base /etc/ssl/certs" | tee -a ${HAPROXY_CONFIG}
echo "    crt-base /etc/ssl/private" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384" | tee -a ${HAPROXY_CONFIG}
echo "        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256" | tee -a ${HAPROXY_CONFIG}
echo "        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "defaults" | tee -a ${HAPROXY_CONFIG}
echo "    mode    tcp" | tee -a ${HAPROXY_CONFIG}
echo "    option  tcplog" | tee -a ${HAPROXY_CONFIG}
echo "    option    dontlognull" | tee -a ${HAPROXY_CONFIG}
echo "        timeout connect 5000" | tee -a ${HAPROXY_CONFIG}
echo "        timeout client  50000" | tee -a ${HAPROXY_CONFIG}
echo "        timeout server  50000" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "frontend tcp_front" | tee -a ${HAPROXY_CONFIG}
echo "    bind *:5000" | tee -a ${HAPROXY_CONFIG}
echo "    bind *:5001" | tee -a ${HAPROXY_CONFIG}
echo "    mode tcp" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "    acl is_5000_port dst_port 5000" | tee -a ${HAPROXY_CONFIG}
echo "    acl is_5001_port dst_port 5001" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "    use_backend primary-psql if is_5000_port" | tee -a ${HAPROXY_CONFIG}
echo "    use_backend replica-psql if is_5001_port" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "backend primary-psql" | tee -a ${HAPROXY_CONFIG}
echo "    mode tcp" | tee -a ${HAPROXY_CONFIG}
echo "    balance roundrobin" | tee -a ${HAPROXY_CONFIG}
echo "    option httpchk GET /leader" | tee -a ${HAPROXY_CONFIG}
echo "    http-check expect status 200" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "    server psql-1 192.168.2.53:6432 check port 8008" | tee -a ${HAPROXY_CONFIG}
echo "    server psql-2 192.168.2.54:6432 check port 8008" | tee -a ${HAPROXY_CONFIG}
echo "    server psql-3 192.168.2.55:6432 check port 8008" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "backend replica-psql" | tee -a ${HAPROXY_CONFIG}
echo "    mode tcp" | tee -a ${HAPROXY_CONFIG}
echo "    balance roundrobin" | tee -a ${HAPROXY_CONFIG}
echo "    option httpchk GET /replica" | tee -a ${HAPROXY_CONFIG}
echo "    http-check expect status 200" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "    server psql-1 192.168.2.53:6432 check port 8008" | tee -a ${HAPROXY_CONFIG}
echo "    server psql-2 192.168.2.54:6432 check port 8008" | tee -a ${HAPROXY_CONFIG}
echo "    server psql-3 192.168.2.55:6432 check port 8008" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
echo "listen stats" | tee -a ${HAPROXY_CONFIG}
echo "    bind *:8404" | tee -a ${HAPROXY_CONFIG}
echo "    mode http" | tee -a ${HAPROXY_CONFIG}
echo "    stats enable" | tee -a ${HAPROXY_CONFIG}
echo "    stats uri /haproxy?stats" | tee -a ${HAPROXY_CONFIG}
echo "    stats refresh 10s" | tee -a ${HAPROXY_CONFIG}
echo "    stats admin if LOCALHOST" | tee -a ${HAPROXY_CONFIG}
echo "    stats auth ${HAPROXY_ACCOUNT}:${HAPROXY_PASSWORD}" | tee -a ${HAPROXY_CONFIG}
echo "" | tee -a ${HAPROXY_CONFIG}
systemctl restart haproxy
systemctl enable haproxy

CHECK_TCP_5000_PORT_SH="/etc/keepalived/check_tcp_5000_port.sh"
KEEPALIVED_CONFIG="/etc/keepalived/keepalived.conf"
AUTH_PASS="abc123"
VIRTUAL_IPADDRESS="192.168.2.50"
echo -e "${INFO_COLOR}-> 安裝 keepalived${COLOR_END}"
apt install -y keepalived netcat
echo "#!/bin/bash" | tee ${CHECK_TCP_5000_PORT_SH}
echo "" | tee -a ${CHECK_TCP_5000_PORT_SH}
echo "if nc -z localhost 5000; then" | tee -a ${CHECK_TCP_5000_PORT_SH}
echo "    exit 0" | tee -a ${CHECK_TCP_5000_PORT_SH}
echo "else" | tee -a ${CHECK_TCP_5000_PORT_SH}
echo "    exit 1" | tee -a ${CHECK_TCP_5000_PORT_SH}
echo "fi" | tee -a ${CHECK_TCP_5000_PORT_SH}
echo "" | tee -a ${CHECK_TCP_5000_PORT_SH}
chmod +x ${CHECK_TCP_5000_PORT_SH}
echo "vrrp_script chk_tcp {" | tee ${KEEPALIVED_CONFIG}
echo "    script \"${CHECK_TCP_5000_PORT_SH}\"" | tee -a ${KEEPALIVED_CONFIG}
echo "    interval 2" | tee -a ${KEEPALIVED_CONFIG}
echo "    weight 2" | tee -a ${KEEPALIVED_CONFIG}
echo "}" | tee -a ${KEEPALIVED_CONFIG}
echo "" | tee -a ${KEEPALIVED_CONFIG}
echo "vrrp_instance VI_1 {" | tee -a ${KEEPALIVED_CONFIG}
echo "    state MASTER" | tee -a ${KEEPALIVED_CONFIG}
echo "    interface eth0" | tee -a ${KEEPALIVED_CONFIG}
echo "    virtual_router_id 2" | tee -a ${KEEPALIVED_CONFIG}

if [ "$DEVICE_NUMBER" -eq 2 ]; then
    echo "    priority 90" | tee -a ${KEEPALIVED_CONFIG}
elif [ "$DEVICE_NUMBER" -eq 3 ]; then
    echo "    priority 80" | tee -a ${KEEPALIVED_CONFIG}
else
    echo "    priority 100" | tee -a ${KEEPALIVED_CONFIG}
fi

echo "    advert_int 1" | tee -a ${KEEPALIVED_CONFIG}
echo "    authentication {" | tee -a ${KEEPALIVED_CONFIG}
echo "        auth_type PASS" | tee -a ${KEEPALIVED_CONFIG}
echo "        auth_pass ${AUTH_PASS}" | tee -a ${KEEPALIVED_CONFIG}
echo "    }" | tee -a ${KEEPALIVED_CONFIG}
echo "    virtual_ipaddress {" | tee -a ${KEEPALIVED_CONFIG}
echo "        ${VIRTUAL_IPADDRESS}" | tee -a ${KEEPALIVED_CONFIG}
echo "    }" | tee -a ${KEEPALIVED_CONFIG}
echo "    track_script {" | tee -a ${KEEPALIVED_CONFIG}
echo "        chk_tcp" | tee -a ${KEEPALIVED_CONFIG}
echo "    }" | tee -a ${KEEPALIVED_CONFIG}
echo "}" | tee -a ${KEEPALIVED_CONFIG}
echo "" | tee -a ${KEEPALIVED_CONFIG}
systemctl start keepalived
systemctl enable keepalived

echo -e "${INFO_COLOR}-> 完成建置，重啟開機後，請使用 ssh root@${ETH0_IP_ADDRESS} 登入${COLOR_END}"
apt clean
reboot