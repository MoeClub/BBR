#!/bin/bash
# ver 4.19

apt update
apt install -y make gcc linux-headers-$(uname -r)

wget -qO /tmp/tcp_bbr.c "https://github.com/MoeClub/BBR/raw/master/src/$(uname -r |cut -d"-" -f1 |cut -d"." -f1-2)/tcp_bbr.c"
wget -qO /tmp/Makefile "https://github.com/MoeClub/BBR/raw/master/Makefile"

cd /tmp
make && make install

