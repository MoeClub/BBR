obj-m := tcp_bbr.o

all:
	make -C /lib/modules/`uname -r`/build M=`pwd` modules CC=`which gcc`
	
clean:
	make -C /lib/modules/`uname -r`/build M=`pwd` clean

install:
	cp -rf tcp_bbr.ko /lib/modules/`uname -r`/kernel/net/ipv4
	insmod /lib/modules/`uname -r`/kernel/net/ipv4/tcp_bbr.ko 2>/dev/null || true
	depmod -a
	sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
	while [ -z "$$(sed -n '$$p' /etc/sysctl.conf)" ]; do sed -i '$$d' /etc/sysctl.conf; done
	sed -i '$$a\net.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr\n\n' /etc/sysctl.conf
	sysctl -p

uninstall:
	rm -rf /lib/modules/`uname -r`/kernel/net/ipv4/tcp_bbr.ko
	sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
	while [ -z "$$(sed -n '$$p' /etc/sysctl.conf)" ]; do sed -i '$$d' /etc/sysctl.conf; done
	sysctl -p
