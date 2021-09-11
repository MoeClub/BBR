#!/bin/bash
# By MoeClub

[ "$1" != "-f" ] && [ ! -f "/lib/modules/$(uname -r)/kernel/net/ipv4/tcp_bbr.ko" ] && echo "This Kernel Not Support BBR by Default." && exit 1

installDep=()
for dep in $(echo "gcc,make" |sed 's/,/\n/g'); do command -v "${dep}" >/dev/null || installDep+=("${dep}"); done
ls -1 "/usr/src" |grep -q "^linux-headers-$(uname -r)" || installDep+=("linux-headers-$(uname -r)")

if [ "${#installDep[@]}" -gt 0 ]; then
  apt update
  apt install -y "${installDep[@]}"
  if [ $? -ne 0 ]; then
    echo "Install Package Fail."
    exit 1
  fi
fi

kernelVer=$(uname -r |cut -d- -f1 |cut -d. -f1-2)
[ ! -n "${kernelVer}" ] && echo "No Found Kernel Version." && exit 1

wget -qO /tmp/tcp_bbr.c "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/net/ipv4/tcp_bbr.c?h=v${kernelVer}"
[ $? -ne 0 ] && echo "Invalid Kernel Version." && exit 1

wget -qO /tmp/Makefile "https://github.com/MoeClub/BBR/raw/master/Makefile"
[ $? -ne 0 ] && echo "Invalid Make File." && exit 1


# bbr_min_rtt_win_sec
sed -i 's|static const u32 bbr_min_rtt_win_sec[^;]*;|static const u32 bbr_min_rtt_win_sec = 13;|g' /tmp/tcp_bbr.c

# bbr_probe_rtt_mode_ms
sed -i 's|static const u32 bbr_probe_rtt_mode_ms[^;]*;|static const u32 bbr_probe_rtt_mode_ms = 56;|g' /tmp/tcp_bbr.c

# bbr_min_tso_rate
sed -i 's|static const int bbr_min_tso_rate[^;]*;|static const int bbr_min_tso_rate = 256000;|g' /tmp/tcp_bbr.c

# bbr_gain
sed -i 's|static const int bbr_high_gain[^;]*;|static const int bbr_high_gain = BBR_UNIT * (2885 * 2) / 1000 + 1;|g' /tmp/tcp_bbr.c
sed -i 's|static const int bbr_drain_gain[^;]*;|static const int bbr_drain_gain = BBR_UNIT * 2 * 1000 / 2885;|g' /tmp/tcp_bbr.c

# bbr_pacing_gain
sed -i '1h;1!H;$!d;${g;s|static const int bbr_pacing_gain\[\][^;]*;|static const int bbr_pacing_gain[] = \{\n        BBR_UNIT * 16 / 8,\n        BBR_UNIT * 6 / 8,\n        BBR_UNIT * 16 / 8,        BBR_UNIT * 10 / 8,        BBR_UNIT * 14 / 8,\n        BBR_UNIT * 10 / 8,        BBR_UNIT * 12 / 8,        BBR_UNIT * 10 / 8\n\};|g;}' /tmp/tcp_bbr.c

# bbr_full_bw_thresh
sed -i 's|static const u32 bbr_full_bw_thresh[^;]*;|static const u32 bbr_full_bw_thresh = BBR_UNIT * 17 / 16;|g' /tmp/tcp_bbr.c

# bbr_lt_bw
sed -i 's|static const u32 bbr_lt_bw_ratio[^;]*;|static const u32 bbr_lt_bw_ratio = BBR_UNIT / 4;|g' /tmp/tcp_bbr.c
sed -i 's|static const u32 bbr_lt_bw_diff[^;]*;|static const u32 bbr_lt_bw_diff = 8000 / 8;|g' /tmp/tcp_bbr.c

# mark
sed -i 's|^MODULE_DESCRIPTION([^;]*;|MODULE_DESCRIPTION("TCP BBR (Bottleneck Bandwidth and RTT) [SV: '$(date +%Y/%m/%d)' Installed]");|g' /tmp/tcp_bbr.c

cd /tmp
make && make install



