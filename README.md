# Rockpi_E_Postgresql_High_Availability

使用 keepalived + haproxy + etcd + patroni + pgbouncer 建置 postgresql 高可用架構

## 說明

網路上有很多相關建置教學，但是實際安裝起來，還是有點困難，因此將相關過程，建置成腳本，方便本人查詢和提供有相同困擾的朋友使用。

建立起來大概是像騰訊雲這張圖的概念。

![架構圖](https://ask.qcloudimg.com/draft/5217461/bnfhttzw3y.png)

## 建置環境

## 硬體

硬體 : [rock pi e v1.2](https://wiki.radxa.com/RockpiE)
系統 : [rockpie_debian_buster_server_arm64_20210824_0255-gpt.img.gz](https://github.com/radxa/rock-pi-images-released/releases/download/v20210824/rockpie_debian_buster_server_arm64_20210824_0255-gpt.img.gz)
記憶卡: 16G

預設使用三台設備，目前嘗試 Patroni 最少要兩台設備，postgresql 才可讀寫，單一台情況下，只能是唯讀狀態。

設備一

- hostname : psql-1
- eth0 : 192.168.2.53
- eth1 : 192.168.168.153
- HAProxy 狀態網址 : 192.168.2.53:8404/haproxy?stats

設備二

- hostname : psql-2
- eth0 : 192.168.2.54
- eth1 : 192.168.168.154
- HAProxy 狀態網址 : 192.168.2.54:8404/haproxy?stats

設備三 hostname : psql-3

- eth0 : 192.168.2.55
- eth1 : 192.168.168.155
- HAProxy 狀態網址 : 192.168.2.55:8404/haproxy?stats

## 服務說明

### keepalived

用於判定設備的生存狀態，並依照權重，讓其中一台存活設備，生成虛擬IP : 192.168.2.50

### haproxy

讓每台設備都能透過固定的網址或者埠號，來連線到 postgresql 主庫(5000 PORT)及備庫(5000 PORT)。

### etcd

用於備庫間選舉出主庫的服務

### patroni

用於操控 postgresql 的服務

### pgbouncer

postgresql 連線池服務，用於提高效能

## 常用服務查詢指令

操作皆在 root 身份下

腳本建立

```bash
rm -f /root/rockpi-e-postgresql-high-availability.sh
touch /root/rockpi-e-postgresql-high-availability.sh
chmod +x /root/rockpi-e-postgresql-high-availability.sh
nano /root/rockpi-e-postgresql-high-availability.sh
```

腳本執行
設備編號 1 ~ 3

```bash
/root/rockpi-e-postgresql-high-availability.sh 1
```

確認 ETCD 狀態

```bash
etcdctl endpoint status --cluster -w table
```

查看 ETCD 執行紀錄

```bash
journalctl -u etcd -f
```

確認 Patroni 狀態

```bash
patronictl -c /etc/patroni/patroni.yml list
```

查看 Patroni 執行紀錄

```bash
journalctl -u patroni -f
```
