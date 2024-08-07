#!/usr/bin/python
#coding=utf-8

import os
import sys
import subprocess
import json
import fcntl
import http.client

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
# zabbix配置文件
zbx_cfg = '/usr/local/zabbix/etc/zabbix_agent2.conf'
# zabbix_get
zbx_get = '/usr/bin/zabbix_get'
# zabbix_sender
zbx_sender = '/usr/bin/zabbix_sender'

# 获取端口状态
def ports_code():
    host = '127.0.0.1'
    port = int(sys.argv[1])  # Assuming you pass port as a command-line argument
    url = "/"
    headers = {"Content-Type": "application/json"}
    
    try:
        conn = http.client.HTTPConnection(host, port, timeout=10)
        conn.request('GET', url, headers=headers)
        
        response = conn.getresponse()
        code = str(response.status)
        res = response.read().decode("utf-8")
        
        if any(code.startswith(prefix) for prefix in ('20', '30', '40', '50')) or '/' in res:
            print(1)
        else:
            print(0)
        
        return code
    except Exception as e:
        # print(f"Error: {e}")
        print(0)
        return None

if __name__ == '__main__':
  try:
      if len(sys.argv) == 2:
         file_lock()
         ports_code() 
      else:
         print("请输入: python ports_code.py 端口号")
  except Exception as msg:
         # print(msg)
         print(0)
