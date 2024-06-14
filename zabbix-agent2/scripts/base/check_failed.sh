#!/bin/bash
# description:监控用户登录失败多次告警

processName="check_failed.sh"
processNum=$(ps -aux | grep -i "${processName}" | grep -v grep | wc -l)

if [ ${processNum} -ge 5 ]; then
   exit 1
fi

ProgramPath="/usr/local/zabbix"
CONFIGFILE=${ProgramPath}/etc/zabbix_agent2.conf
zbx_sender='/usr/bin/zabbix_sender'
mon=$(date +%B)
h=$(date +%d)
ms=$(date +%H:%M)
#表示字符开头为0就替换为空
h=${h/#0/""}
k=" "
count=`find /var/log/ -iname "secure" -or -iname "auth.log" -or -iname "messages" | xargs grep "$h$k$ms" | egrep 'Failed password' | wc -l`

# 自动发送用户登录失败次数
${zbx_sender} -c ${CONFIGFILE} -k "login.failed" -o ${count}
