#!/bin/bash
ProgramPath="/usr/local/zabbix"
CONFIGFILE=${ProgramPath}/etc/zabbix_agent2.conf
ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
sed -i '/SourceIP=/c SourceIP='${ip}'' ${CONFIGFILE}
sed -i '/Hostname=/c Hostname='${ip}'' ${CONFIGFILE}
