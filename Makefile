obj-m := tcp_bbr.o

all:
	make -C /lib/modules/`uname -r`/build M=`pwd` modules CC=`which gcc`
clean:
	make -C /lib/modules/`uname -r`/build M=`pwd` clean

install:
	cp -rf tcp_bbr.ko /lib/modules/`uname -r`/kernel/net/ipv4
	insmod /lib/modules/`uname -r`/kernel/net/ipv4/tcp_bbr.ko
	depmod -a

uninstall:
	rm -rf /lib/modules/`uname -r`/kernel/net/ipv4/tcp_bbr.ko
