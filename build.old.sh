#!/bin/bash

kernel="4.14.153"
wget --no-check-certificate https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-${kernel}.tar.xz

apt-get update
apt-get install -y build-essential libncurses5-dev libelf-dev bzip2 bc
apt-get build-dep -y linux

tar -Jxvf "./linux-${kernel}.tar.xz" -C /tmp/
cd /tmp/linux-${kernel}

wget --no-check-certificate -qO './net/ipv4/tcp_bbr.c' 'https://raw.githubusercontent.com/MoeClub/BBR/master/tcp_bbr.c'
sed -i '1836a\\nEXPORT_SYMBOL(tcp_snd_wnd_test);' ./net/ipv4/tcp_output.c
sed -i 's/icsk_ca_priv\[[0-9]*/icsk_ca_priv\[120/' ./include/net/inet_connection_sock.h
sed -i 's/^#define ICSK_CA_PRIV_SIZE[[:space:]]*([0-9]* \* sizeof(u64))/#define ICSK_CA_PRIV_SIZE      (16 \* sizeof(u64))/' ./include/net/inet_connection_sock.h

yes "" | make oldconfig
sed -i 's/^CONFIG_TCP_CONG_BBR=.*/CONFIG_TCP_CONG_BBR=m/g' ./.config
scripts/config --disable MODULE_SIG
scripts/config --disable DEBUG_INFO

make deb-pkg
