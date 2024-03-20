#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
###export###
# 语言设置
export LANG="zh_CN.UTF-8"
export LANGUAGE="zh_CN.UTF-8"
#======================================================================
#   System Required:  CentOS Debian Ubuntu or Fedora(32bit/64bit)
#   Description:  A tool to auto-compile & install zabbix_agentd on Linux
#======================================================================
# 脚本版本号
version="20220520"
# zabbix版本号
ZABBIX_VER=v1.0
# 进程目录名
program_name="zabbix"
# 脚本名称
shell_name="check_update.sh"
# 脚本URL
str_install_shell="http://ifly.iflytek.com/get/zabbix/scripts/base/${shell_name}"
# 安装路径
str_program_dir="/usr/local/${program_name}"
# 进程名称
program_server_name="zabbix_server"
program_proxy_name="zabbix_proxy"
program_agentd_name="zabbix_agentd"
# init脚本路径
program_server_init="/etc/init.d/${program_server_name}"
program_proxy_init="/etc/init.d/${program_proxy_name}"
program_agentd_init="/etc/init.d/${program_agentd_name}"
# system路径
program_server_system="/usr/lib/systemd/system/${program_server_name}.service"
program_proxy_system="/usr/lib/systemd/system/${program_proxy_name}.service"
program_agentd_system="/usr/lib/systemd/system/${program_agentd_name}.service"
# system-16路径
program_server_system_16="/lib/systemd/system/${program_server_name}.service"
program_proxy_system_16="/lib/systemd/system/${program_proxy_name}.service"
program_agentd_system_16="/lib/systemd/system/${program_agentd_name}.service"
# zabbix配置文件
program_server_config_file="zabbix_server.conf"
program_proxy_config_file="zabbix_proxy.conf"
program_agentd_config_file="zabbix_agent2.conf"
# zabbix sender
zbx_sender='/usr/local/zabbix/bin/zabbix_sender'
# 下载地址
download_get="http://ifly.iflytek.com/get"
# 下载最新稳定版地址
download_url="http://ifly.iflytek.com/get/zabbix/sources/stable"
# 下载最新测试版地址
download_dev_url="http://ifly.iflytek.com/get/zabbix/sources/dev"
# init脚本URL
download_agentd_init_url="http://ifly.iflytek.com/get/zabbix/init/zabbix_agentd.init"
download_server_init_url_sup="http://ifly.iflytek.com/get/zabbix/init/sup/zabbix_server.init"
download_proxy_init_url_sup="http://ifly.iflytek.com/get/zabbix/init/sup/zabbix_proxy.init"
download_agentd_init_url_sup="http://ifly.iflytek.com/get/zabbix/init/sup/zabbix_agentd.init"
# system脚本URL
download_server_system_url_sup="http://ifly.iflytek.com/get/zabbix/system/sup/zabbix_server.service"
download_proxy_system_url_sup="http://ifly.iflytek.com/get/zabbix/system/sup/zabbix_proxy.service"
download_agentd_system_url_sup="http://ifly.iflytek.com/get/zabbix/system/sup/zabbix_agentd.service"
download_agentd_system_url="http://ifly.iflytek.com/get/zabbix/system/zabbix_agentd.service"
# 日期
date_time=$(date +"%Y%m%d%H%M%S")
# 系统名称
platform=$(python2 -c 'import platform;print platform.dist()[0].lower()')
# 版本号
release=$(python2 -c 'import platform;print platform.dist()[1]')
# IP地址
ip=$(python2 -c "import socket;print([(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1])")
# iptables防火墙状况
iptables_code=$(iptables -nvL 2> /dev/null | grep -qi '0.0.0.0' && echo 1)
# firewalld防火墙状况
firewall_code=$(firewall-cmd --state 2> /dev/null | grep -qi 'running' && echo 1)
# ufw防火墙状况
ufw_code=$(ufw status 2> /dev/null | grep -qi 'ALLOW' && echo 1)
# 脚本进程数目
processNum=$(ps -aef | grep -v sudo | grep "${shell_name}" | grep -v grep | wc -l)
if [ "${processNum}" -gt "2" ]; then
  echo "脚本已经重复运行"
  exit 1
fi
fun_clangcn(){
    local clear_flag=""
    clear_flag=$1
    if [[ ${clear_flag} == "clear" ]]; then
        clear
    fi
    echo ""
    echo "+------------------------------------------------------------+"
    echo "|      zabbix for Linux Server                               |" 
    echo "|      A tool to auto-compile & install zabbix on Linux      |"
    echo "+------------------------------------------------------------+"
    echo ""
}
fun_set_text_color(){
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}
shell_update(){
    fun_clangcn "clear"
    echo "检查并升级shell..."
    remote_shell_version=`wget  -qO- ${str_install_shell} | sed -n '/'^version'/p' | cut -d\" -f2`
    if [ ! -z ${remote_shell_version} ]; then
        if [[ "${version}" != "${remote_shell_version}" ]];then
            echo -e "${COLOR_GREEN}Found a new version,update now!!!${COLOR_END}"
            echo
            echo -n "Update shell ..."
            if ! wget -N  -qO $0 ${str_install_shell}; then
                echo -e " [${COLOR_RED}failed${COLOR_END}]"
                echo
                exit 1
            else
                chmod +x ${shell_name}
                sudo su -c "rm -rf /tmp/install-zabbix.sh && wget ${download_get}/zabbix/install-zabbix.sh -O /tmp/install-zabbix.sh && chmod 700 /tmp/install-zabbix.sh && cd /tmp && (nohup ./install-zabbix.sh update &) && chown -R zabbix:zabbix /usr/local/zabbix && chmod -R 775 /usr/local/zabbix"
                echo -e " [${COLOR_GREEN}OK${COLOR_END}]"
                echo
                echo -e "${COLOR_GREEN}Please Re-run${COLOR_END} ${COLOR_PINK}$0 ${clang_action}${COLOR_END}"
                echo
            fi
            exit 1
        fi
    fi
}
shell_update
${zbx_sender} -c ${str_program_dir}/etc/${program_agentd_config_file} -k "shell.version" -o ${version}
