#!/usr/bin/python
#coding=utf-8

import time
import os
import sys
import subprocess
import json
import re
import socket
import threading
import argparse
import http.client
import fcntl

pidfile = 0
# 防止脚本重复执行
def file_lock():
    global pidfile
    pidfile = open(os.path.realpath(__file__), "r")
    try:
        fcntl.flock(pidfile, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except:
        sys.exit("2")

# 定义执行命令
def execute_cmd(cmd):
    """
    命令执行，并获取返回状态与执行结果
    :param cmd: 要执行的命令
    :return: 字典包含 执行的状态码和执行的正常和异常输出, 0为正常，1为异常
    """
    cmd_res = {'status': 1, 'stdout': '', 'stderr': ''}
    try:
        # res = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        res = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,encoding="utf-8")
        res_stdout, res_stderr = res.communicate()
        cmd_res['status'] = res.returncode
        cmd_res['stdout'] = res_stdout
        cmd_res['stderr'] = res_stderr
    except Exception as e:
        cmd_res['stderr'] = e
    finally:
        return cmd_res

# 获取本机IP
zbx_ip = "/usr/bin/zabbix_get -s 127.0.0.1 -k agent.hostname"
# 发送本机IP
senderhostname = execute_cmd(zbx_ip)['stdout'].strip()
# 排除列表
drop_list = ['systemd','dnsmasq','cupsd','smtpd','master','^.*:95','ssh.*']
drop_str = "|".join(drop_list)
# 获取端口列表
port_cmd = (""" for port in $(ps -aux | grep -i 'ss -atunlp' | grep -v grep >/dev/null 2>&1 || ss -atunlp | grep -v grep | grep LISTEN | egrep -vw '%s' | sed "s#::#FF#g" | egrep -v '(ffff)' | grep users | sort -u | uniq | awk '{print $5,$NF}' | awk -F "[ :]+" '{print $2,$NF}' | awk '{if(length($2)>1) print $0}' | awk -F '[=,()" ]+' '{print $1}' | sort -u | uniq);do curl -s --max-time 1 --insecure http://127.0.0.1:$port -o /dev/null && echo $port;done """ % (drop_str))
port_lists = execute_cmd(port_cmd)['stdout'].strip().split("\n")
# 获取pid信息
pidstat_cmd = execute_cmd("which pidstat")['stdout'].strip()
# 定义端口key
zbx_port_key = 'port_status'
# 定义进程key
zbx_find_key = 'port.find'
# zabbix配置文件
zbx_cfg = '/usr/local/zabbix/etc/zabbix_agent2.conf'
# zabbix_get
zbx_get = '/usr/bin/zabbix_get'
# zabbix_sender
zbx_sender = '/usr/bin/zabbix_sender'
# 临时文件
zbx_tmp_port_file='/usr/local/zabbix/scripts/base/.zabbix_port_find'
zbx_tmp_port_status_file='/usr/local/zabbix/scripts/base/.zabbix_port_status'

# 获取pid
def getDisplayPid(processId):
    pid = execute_cmd(""" ss -atunlp | grep -v grep | grep LISTEN | grep -i '^.*:%s' | sed "s#::#FF#g" | egrep -v '(ffff)' | grep users | sort -u | uniq | awk '{print $5,$NF}' | awk -F "[ :]+" '{print $2,$NF}' | awk '{if(length($2)>1) print $0}' | awk -F '[=,()" ]+' '{print $4}' | sort -u | uniq | head -n 1 """ % str(processId))['stdout'].strip()
    return pid

# 获取进程用户
def getDisplayUser(processId):
    user = execute_cmd("ps aux| grep -v grep | grep %s | awk '{print $1}' | head -n 1" % str(processId))['stdout'].strip()
    return user

# 获取工作目录
def getDisplayCwd(processId):
    # cwd = execute_cmd("ps -p %s -o comm=" % str(processId))['stdout'].strip()
    cwd = execute_cmd("readlink -f /proc/%s/cwd" % str(processId))['stdout'].strip()
    cwd = cwd.split('/')[-1]
    return cwd

# 获取运行目录
def getDisplayExe(processId):
    exe = execute_cmd("readlink -f /proc/%s/exe" % str(processId))['stdout'].strip()
    exe = exe.split('/')[-1]
    return exe

# 获取文件描述符
def getDisplayLimits(processId):
    limits = execute_cmd("cat /proc/%s/limits | egrep -i 'open files'| awk '{print $4}'" % str(processId))['stdout'].strip()
    return limits

# 获取端口状态
def getDisplayStatus(processId):
    status=''
    host='127.0.0.1'
    port='%s' % str(processId)
    header={"Content-Type":"application/json"}
    payload = ''
    url="/"
    data={}
    data = json.dumps(data)
    conn=http.client.HTTPConnection(host, port, timeout=10)
    conn.request('GET', url, payload, header)
    response = conn.getresponse()
    res=response.read().decode("utf-8")
    code = str(response.status)
    if any(code.startswith(prefix) for prefix in ('20', '30', '40', '50')) or '/' in res:
       code = {"status":1}
    else:
       code = {"status":0}
    return code

def port_truncate():
    '''
      用于清空zabbix_sender使用的临时文件
    '''
    with open(zbx_tmp_port_file,'w+') as fn: fn.truncate()


def port_discovery():
    port_proce = []
    pidPortSet = set()
    pnameSet = set()
    for line in port_lists:
        line = line.strip()
        args = line.split()
        port = args[0]
        pid = getDisplayPid(port)
        cwd = getDisplayCwd(pid)
        exe = getDisplayExe(pid)
        user = getDisplayUser(pid)
        status = getDisplayStatus(port)
        
        port_proce.append({"{#PORT}":port,"{#PID}":pid,"{#PWD}":cwd,"{#EXE}":exe,"{#USER}":user,"{#CODE}":status})
        port_truncate()
        time.sleep(0.1)
        zbx_port = json.dumps({'data': port_proce},ensure_ascii=False)
        zbx_file = ("%s %s %s" %(senderhostname,zbx_find_key,zbx_port))
        with open(zbx_tmp_port_file,'a+') as file_obj: file_obj.write(zbx_file + '\n')

    return json.dumps({'data': port_proce}, sort_keys=True, indent=4,separators=(',', ':'),ensure_ascii=False)


def send_data_port_zabbix():
    '''
      调用zabbix_sender命令，将收集的key和value发送至zabbix server
    '''
    port_discovery()
    zbx_sender_cmd = "%s -c %s -i %s -vv -r" %(zbx_sender,zbx_cfg,zbx_tmp_port_file)
    # print(zbx_sender_cmd)
    zbx_sender_status = execute_cmd(zbx_sender_cmd)
    if zbx_sender_status['status'] == 0:
       print(1)
    else:
       print(0)
    # print(zbx_sender_status)
    # print(zbx_sender_result)

def port_status_truncate():
    '''
      用于清空zabbix_sender使用的临时文件
    '''
    with open(zbx_tmp_port_status_file,'w+') as fn: fn.truncate()

portstat_dict = {
  "status":"端口状况"
}

def get_port(port):
    port_status_truncate()
    time.sleep(0.1)
    port_status = getDisplayStatus(port)
    data_dict = dict(**port_status)
    # print(port_data)
    for portkey in data_dict.keys():
        if portkey in portstat_dict.keys():
            cur_key = portstat_dict[portkey]
            zbx_data = "%s %s[%s,%s] %s" %(senderhostname,zbx_port_key,cur_key,port,data_dict[portkey])
            with open(zbx_tmp_port_status_file,'a+') as file_obj: file_obj.write(zbx_data + '\n')
            # print(zbx_data)

port_threads = []

def zbx_tmp_port_create():
    '''
      创建zabbix_sender发送的文件内容
    '''

    for line in port_lists:
        line = line.strip()
        args = line.split()
        port = args[0]
        th = threading.Thread(target=get_port,args=((port,)))
        th.start()
        port_threads.append(th)

def send_data_port_status_zabbix():
    '''
      调用zabbix_sender命令，将收集的key和value发送至zabbix server
    '''
    zbx_tmp_port_create()
    for get_portdata in port_threads:
        get_portdata.join()
    zbx_sender_cmd = "%s -c %s -i %s -vv -r" %(zbx_sender,zbx_cfg,zbx_tmp_port_status_file)
    # print(zbx_sender_cmd)
    zbx_sender_status = execute_cmd(zbx_sender_cmd)
    if zbx_sender_status['status'] == 0:
       print(1)
    else:
       print(0)
    # print(zbx_sender_status)
    # print(zbx_sender_result)


def cmd_line_opts(arg=None):
    class ParseHelpFormat(argparse.HelpFormatter):
        def __init__(self, prog, indent_increment=5, max_help_position=50, width=200):
            super(ParseHelpFormat, self).__init__(prog, indent_increment, max_help_position, width)

    parse = argparse.ArgumentParser(description='端口自动发现监控',
                                    formatter_class=ParseHelpFormat)
    parse.add_argument('--version', '-v', action='version', version="0.1", help='查看版本')
    parse.add_argument('--port_discovery', action='store_true', help='自动发现所有端口')
    parse.add_argument('--port_send', action='store_true', help='检查端口发现是否正常运行')
    parse.add_argument('--port_status_send', action='store_true', help='检查端口状况是否正常运行')
    
    if arg:
        return parse.parse_args(arg)
    if not sys.argv[1:]:
        return parse.parse_args(['-h'])
    else:
        return parse.parse_args()

if __name__ == '__main__':
  try:
      opts = cmd_line_opts()
      if(len(port_discovery()) <= 17 ):
         print(0)
      else:
           if opts.port_discovery:
              print(port_discovery())
           elif opts.port_send:
                file_lock()
                send_data_port_zabbix()
           elif opts.port_status_send:
                file_lock()
                send_data_port_status_zabbix()
           else:
                cmd_line_opts(arg=['-h'])
  except Exception as msg:
         # print(msg)
         print(0)
