#!/bin/bash
# description:判断跟踪表值是否超过70%
processName="check_nf_conntrack.sh"
processNum=$(ps -aef | grep -i "${processName}" | grep -v grep | wc -l)

if [ "${processNum}" -gt "5" ]; then
    exit 1
fi

ProgramPath="/usr/local/zabbix"
CONFIGFILE=${ProgramPath}/etc/zabbix_agent2.conf
zbx_sender='zabbix_sender'
x=0.7
nf_conntrack_max=$(cat /proc/sys/net/nf_conntrack_max)
nf_conntrack_number=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
number=$(awk -v a=$nf_conntrack_max -v b=$x 'BEGIN{printf "%.1f\n",a*b}')
percent=$(awk -v num1=$nf_conntrack_number -v num2=$number 'BEGIN{print(num1>num2)?"0":"1"}')

# 自动发送跟踪表状况
${zbx_sender} -c ${CONFIGFILE} -k "conntrack.info" -o ${percent} >/dev/null 2>&1

# 自动发送跟踪表数目
${zbx_sender} -c ${CONFIGFILE} -k "conntrack.number" -o ${nf_conntrack_number} >/dev/null 2>&1
