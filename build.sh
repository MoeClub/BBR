# ver 4.19

apt update
apt install -y make gcc linux-headers-$(uname -r)

wget -qO /tmp/tcp_bbr.c https://github.com/MoeClub/BBR/raw/master/src/tcp_bbr.c
wget -qO /tmp/Makefile https://github.com/MoeClub/BBR/raw/master/Makefile

cd /tmp
make

