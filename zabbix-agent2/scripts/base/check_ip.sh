#!/bin/bash
ProgramPath="/usr/local/zabbix"
CONFIGFILE=${ProgramPath}/etc/zabbix_agent2.conf
ip=$(python2 -c "import socket;print([(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1])")
sed -i '/SourceIP=/c SourceIP='${ip}'' ${CONFIGFILE}
sed -i '/Hostname=/c Hostname='${ip}'' ${CONFIGFILE}
