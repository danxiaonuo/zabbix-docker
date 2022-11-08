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
zbx_ip = "zabbix_get -s 127.0.0.1 -k agent.hostname"
# 发送本机IP
senderhostname = execute_cmd(zbx_ip)['stdout'].strip()
# 排除列表
drop_list = ['systemd','dnsmasq','cupsd','smtpd','master','^.*:95','ssh.*']
drop_str = "|".join(drop_list)
# 获取端口列表
port_cmd = (""" ss -atunlp | grep -v grep | grep LISTEN | egrep -vw '%s' | sed "s#::#FF#g" | egrep -v '(ffff)' | grep users | sort -u | uniq | awk '{print $5,$NF}' | awk -F "[ :]+" '{print $2,$NF}' | awk '{if(length($2)>1) print $0}' | awk -F '[=,()" ]+' '{print $1,$2,$4,$6}' | sort -u | uniq """ % (drop_str))
port_lists = execute_cmd(port_cmd)['stdout'].strip().split("\n")
# 获取pid信息
pidstat_cmd = execute_cmd("which pidstat")['stdout'].strip()
# 定义端口key
zbx_port_key = 'port.discovery'
# 定义进程key
zbx_pid_key = 'pid_status'
# zabbix配置文件
zbx_cfg = '/usr/local/zabbix/etc/zabbix_agent2.conf'
# zabbix_get
zbx_get = 'zabbix_get'
# zabbix_sender
zbx_sender = 'zabbix_sender'
# 临时文件
zbx_tmp_port_file='/usr/local/zabbix/scripts/base/.zabbix_port_discovery'
zbx_tmp_pid_file='/usr/local/zabbix/scripts/base/.zabbix_pid_discovery'
# 定义pid字典
pidstat_dict = {
       "%usr":"进程在用户空间占用cpu的使用率",
       "%system":"进程在内核空间占用cpu的使用率",
       "%guest":"进程在虚拟机占用cpu的使用率", 
       "%wait":"进程等待cpu时间的使用率",
       "%CPU":"进程使用cpu的使用率",
       "minflt/s":"从内存中加载数据时每秒出现的次要错误的数目",
       "majflt/s":"从内存中加载数据时每秒出现的主要错误的数目",
       "VSZ":"进程使用的虚拟内存",
       "RSS":"进程使用的物理内存",
       "%MEM":"进程使用物理内存的使用率",
       "kB_rd/s":"进程每秒从磁盘读取的数据量",
       "kB_wr/s":"进程每秒向磁盘写入的数据量",
       "kB_ccwr/s":"进程每秒任务取消写入磁盘的数据量",
       "iodelay":"任务的I/O阻塞延迟时间",
       "cswch/s":"每秒主动任务上下文切换的次数",
       "nvcswch/s":"每秒被动任务上下文切换的次数",
       "threads":"进程线程总数"
    
}

pid_threads = []

def get_status(cmd,pid):
    pidStr = """ {0} -p {1} -h -druIvw | grep -v grep | grep -v '(^$|^Linux)' | sed -e 's/#//g' -e 's/AM//g' -e 's/PM//g' -e "/^$/d" -e "1d" """.format(cmd,pid)
    value = execute_cmd(pidStr)['stdout'].strip().split("\n") 
    kv = []
    for i in value[0].split(' '):
        if i != '':
            kv.append(i)

    vv = []
    for i in value[1].split(' '):
        if i != '':
            vv.append(i)

    data = dict(zip(kv,vv))
    return data

def get_thread(pid):
    value = execute_cmd("cat /proc/%s/status | egrep -i Threads | awk '{print $2}'" % str(pid))['stdout'].strip()
    data = {"threads":value}
    return data

def pid_truncate():
    '''
      用于清空zabbix_sender使用的临时文件
    '''
    with open(zbx_tmp_pid_file,'w+') as fn: fn.truncate()

def get_pid(pid):
    pid_truncate()
    time.sleep(0.1)
    pid_data = get_status(pidstat_cmd,pid)
    # thread_data = get_thread(pid)
    # data_dict = dict(list(pid_data.items())+list(thread_data.items()))
    data_dict = dict(**pid_data)
    for pidkey in data_dict.keys():
        if pidkey in pidstat_dict.keys():
            cur_key = pidstat_dict[pidkey]
            zbx_data = "%s %s[%s,%s] %s" %(senderhostname,zbx_pid_key,cur_key,pid,data_dict[pidkey])
            with open(zbx_tmp_pid_file,'a+') as file_obj: file_obj.write(zbx_data + '\n') 
    
def zbx_tmp_pid_create():
    '''
      创建zabbix_sender发送的文件内容
    '''
    for line in port_lists:
        line = line.strip()
        args = line.split()
        pid = args[2]
        th = threading.Thread(target=get_pid,args=((pid,)))
        th.start()
        pid_threads.append(th)

def send_data_pid_zabbix():
    '''
      调用zabbix_sender命令，将收集的key和value发送至zabbix server
    '''
    zbx_tmp_pid_create()
    for get_piddata in pid_threads:
        get_piddata.join()
    zbx_sender_cmd = "%s -c %s -i %s -vv -r" %(zbx_sender,zbx_cfg,zbx_tmp_pid_file)
    # print(zbx_sender_cmd)
    zbx_sender_status = execute_cmd(zbx_sender_cmd)
    if zbx_sender_status['status'] == 0:
       print(1)
    else:
       print(0)
    # print(zbx_sender_status)
    # print(zbx_sender_result)

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
        name = args[1]
        pid = args[2]
        fd = args[3]
        limits = getDisplayLimits(pid)
        cwd = getDisplayCwd(pid)
        exe = getDisplayExe(pid)
        user = getDisplayUser(pid)
        
        # pid,port去重
        pidPortEntry = (pid, port)
        if pidPortEntry in pidPortSet:
           continue
        else:
            pidPortSet.add(pidPortEntry)

        # 进程名称去重
        pnameEntry = (name, exe, port)
        if pnameEntry in pnameSet:
           continue
        else:
            pnameSet.add(pnameEntry)

        # 判断进程路径是否为空
        if(len(cwd) == 0):
            cwd="/"
        port_proce.append({"{#NAME}":name,"{#PORT}":port,"{#PID}":pid,"{#LIMITS}":limits,"{#PWD}":cwd,"{#EXE}":exe,"{#FD}":fd,"{#USER}":user})
        port_truncate()
        time.sleep(0.1)
        zbx_port = json.dumps({'data': port_proce},ensure_ascii=False)
        zbx_file = ("%s %s %s" %(senderhostname,zbx_port_key,zbx_port))
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

def cmd_line_opts(arg=None):
    class ParseHelpFormat(argparse.HelpFormatter):
        def __init__(self, prog, indent_increment=5, max_help_position=50, width=200):
            super(ParseHelpFormat, self).__init__(prog, indent_increment, max_help_position, width)

    parse = argparse.ArgumentParser(description='端口自动发现监控',
                                    formatter_class=ParseHelpFormat)
    parse.add_argument('--version', '-v', action='version', version="0.1", help='查看版本')
    parse.add_argument('--port_discovery', action='store_true', help='自动发现所有端口')
    parse.add_argument('--port_send', action='store_true', help='检查端口发现是否正常运行')
    parse.add_argument('--pid_send', action='store_true', help='检查端口性能发现是否正常运行')
    
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
           elif opts.pid_send:
                file_lock()
                send_data_pid_zabbix()        
           else:
                cmd_line_opts(arg=['-h'])
  except Exception as msg:
         # print(msg)
         print(0)
