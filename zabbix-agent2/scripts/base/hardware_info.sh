#!/bin/bash

ProgramPath="/usr/local/zabbix"
CONFIGFILE=${ProgramPath}/etc/zabbix_agent2.conf
zbx_sender='zabbix_sender'

processName="hardware_info.sh"
processNum=$(ps -aef | grep -v sudo | grep "${processName}" | grep -v grep | wc -l)
 
if [ "${processNum}" -gt "2" ]; then
  exit 1
fi

# 获取服务器厂家
${zbx_sender} -c ${CONFIGFILE} -k "system.manufacturer" -o "$(sudo dmidecode -s system-manufacturer | sed "/^#/d")" >/dev/null 2>&1

# 获取服务器类型
${zbx_sender} -c ${CONFIGFILE} -k "system.product.name" -o "$(sudo dmidecode -s system-product-name | sed "/^#/d")" >/dev/null 2>&1

# 获取服务器SN号
${zbx_sender} -c ${CONFIGFILE} -k "system.serial.number" -o "$(sudo dmidecode -s system-serial-number | sed "/^#/d")" >/dev/null 2>&1

# 获取服务器UUID
${zbx_sender} -c ${CONFIGFILE} -k "system.uuid" -o "$(sudo dmidecode -s system-uuid | sed "/^#/d")" >/dev/null 2>&1

# 获取主板生产厂家
${zbx_sender} -c ${CONFIGFILE} -k "baseboard.manufacturer" -o "$(sudo dmidecode -s baseboard-manufacturer | sed "/^#/d")" >/dev/null 2>&1

# 获取主板产品名称
${zbx_sender} -c ${CONFIGFILE} -k "baseboard.product.name" -o "$(sudo dmidecode -s baseboard-product-name | sed "/^#/d")" >/dev/null 2>&1

# 获取主板版本
${zbx_sender} -c ${CONFIGFILE} -k "baseboard.version" -o "$(sudo dmidecode -s baseboard-version | sed "/^#/d")" >/dev/null 2>&1

# 获取主板序列号
${zbx_sender} -c ${CONFIGFILE} -k "baseboard.serial.number" -o "$(sudo dmidecode -s baseboard-serial-number | sed "/^#/d")" >/dev/null 2>&1

# 获取操作系统名称
${zbx_sender} -c ${CONFIGFILE} -k "os.name" -o "$(python2 -c "import platform;print(platform.linux_distribution()[0])" | sed "/^#/d")" >/dev/null 2>&1

# 获取操作系统类型
${zbx_sender} -c ${CONFIGFILE} -k "os.type" -o "$(uname -o | sed "/^#/d")" >/dev/null 2>&1

# 获取操作系统版本
${zbx_sender} -c ${CONFIGFILE} -k "os.version" -o "$(python2 -c "import platform;print(platform.linux_distribution()[1])" | sed "/^#/d")" >/dev/null 2>&1

# 获取CPU型号
${zbx_sender} -c ${CONFIGFILE} -k "cpu.module" -o "$(cat /proc/cpuinfo | awk -F': '+ '/model name/{print $2}' | uniq | sed "/^#/d")" >/dev/null 2>&1

# 获取硬盘容量
${zbx_sender} -c ${CONFIGFILE} -k "disk.capacity" -o "$(lsblk -b | awk '{if ($6 == "disk") total += $4} END {if (total >= 1024*1024*1024*1024) {printf "%.2f TB\n", total/(1024*1024*1024*1024)} else {printf "%.2f GB\n", total/(1024*1024*1024)}}'  | sed "/^#/d")" >/dev/null 2>&1
