#!/bin/sh

useradd test -d/home/test;cd /home/test;yum -y install go;wget https://github.com/coyove/goflyway/releases/download/1.3.0a/goflyway_linux_amd64.tar.gz;tar -zxvf goflyway_linux_amd64.tar.gz;echo 'exec /home/test/goflyway -k=1231';./goflyway -k=1231
git clone https://github.com/wkdhuiyi/ss-fly/;sh ss-fly/ss-fly.sh -i paic1234 7529;sh ss-fly/ss-fly.sh -bbr
sysctl net.ipv4.tcp_available_congestion_control
