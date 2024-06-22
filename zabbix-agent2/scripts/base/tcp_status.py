#!/usr/bin/python
#coding=utf-8

import sys
import os
import subprocess
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

# 临时文件
tmp_file = "/usr/local/zabbix/scripts/base/.tcp_connect_status.txt"
# 获取tcp状态
tcp_conn_status_cmd = "ss -tan|awk 'NR>1{++S[$1]}END{for (a in S) print a,S[a]}'"
# 获取本机IP
zbx_ip = "/usr/bin/zabbix_get -s 127.0.0.1 -k agent.hostname"
# zabbix发送数据命令
zbx_sender_bin = "/usr/bin/zabbix_sender"
# zabbix配置文件
zbx_conf_path = '/usr/local/zabbix/etc/zabbix_agent2.conf'

# tcp 连接状态码
tcp_conn_status_dic = {
        'UNCONN': 0,
        'LISTEN': 0,
        'SYN-RECV': 0,
        'SYN-SENT': 0,
        'ESTAB': 0,
        'TIME-WAIT': 0,
        'CLOSING': 0,
        'CLOSE-WAIT': 0,
        'LAST-ACK': 0,
        'FIN-WAIT-1': 0,
        'FIN-WAIT-2': 0,
}

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

def get_status(cmd):
    value = execute_cmd(tcp_conn_status_cmd)['stdout'].strip().split()
    # print(value)
    data = dict(zip(value[0::2], value[1::2]))
    return data

def get_tcp_num():
    tcp_data = get_status(execute_cmd)
    tcp_conn_status_dic.update(tcp_data)
    return tcp_conn_status_dic

def send_tcp_status():
    # 获取本机IP
    senderhostname = execute_cmd(zbx_ip)['stdout'].strip()
    # 获取TCP连接数状态
    tcp_connect_status = get_tcp_num()
    with open(tmp_file, mode='w+') as f_zs:
         for status, number in tcp_conn_status_dic.items():
             # print(status, number)
             f_zs.write("{0} tcp.connect.status[{1}] {2}  \n".format(senderhostname, status.lower(), number))         
    # 发送数据给zabbix
    sender_data_ret = execute_cmd('{0} -c {1} -i {2}'.format(zbx_sender_bin, zbx_conf_path, tmp_file))
    # 当命令执行成功，并且找到"failed: 0"
    if sender_data_ret['status'] == 0:
       os.remove(tmp_file)  # 删除临时文件
    else:
         sender_data_ret['stdout']
         # print(sender_data_ret['stdout'])
    return sender_data_ret

 
if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == "sender_data":
       file_lock()
       send_tcp_status()
    else:
        print("请输入: python tcp_status.py sender_data")
