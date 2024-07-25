#!/usr/bin/python
# -*- coding: utf-8 -*-

import sys
import os
import json
import time
import subprocess
import fcntl

# 防止脚本重复执行
def file_lock():
    pidfile = open(os.path.realpath(__file__), "r")
    try:
        fcntl.flock(pidfile, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except:
        sys.exit("2")

# 发送指令
zbx_key_discovery = "zbx.iostat.discovery"
zbx_key_status = "zbx.iostat.status"
# 临时文件
tmp_file_discovery = "/usr/local/zabbix/scripts/base/.zbx_iostat_discovery.txt"
tmp_file_status = "/usr/local/zabbix/scripts/base/.zbx_iostat_status.txt"
# 获取列表
iostat_list_cmd = "iostat | awk '/^[a-z]/ && !/^avg-cpu/ && !/^dm-/ && !/^loop*/ {print $1}'"
# 获取状态
iostat_status_cmd = "iostat -x -d 3 3 | awk '/^[a-z]/ && !/^avg-cpu/ && !/^dm-/ && !/^loop*/ {printf \"%s %.2f\\n\", $1, $NF}'"
# 获取本机IP
zbx_ip = "/usr/bin/zabbix_get -s 127.0.0.1 -k agent.hostname"
# zabbix发送数据命令
zbx_sender_bin = "/usr/bin/zabbix_sender"
# zabbix配置文件
zbx_conf_path = '/usr/local/zabbix/etc/zabbix_agent2.conf'

def execute_cmd(cmd):
    """
    命令执行，并获取返回状态与执行结果
    :param cmd: 要执行的命令
    :return: 字典包含 执行的状态码和执行的正常和异常输出, 0为正常，1为异常
    """
    cmd_res = {'status': 1, 'stdout': '', 'stderr': ''}
    try:
        res = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        res_stdout, res_stderr = res.communicate()
        cmd_res['status'] = res.returncode
        cmd_res['stdout'] = res_stdout.decode('utf-8')
        cmd_res['stderr'] = res_stderr.decode('utf-8')
    except Exception as e:
        cmd_res['stderr'] = str(e)
    finally:
        return cmd_res

def truncate_discovery():
    '''
      用于清空zabbix_sender使用的临时文件
    '''
    with open(tmp_file_discovery,'w+') as fn: fn.truncate()

def truncate_status():
    '''
      用于清空zabbix_sender使用的临时文件
    '''
    with open(tmp_file_status,'w+') as fn: fn.truncate()


def send_iostat_discovery():
    # 获取设备列表
    iostat_list = execute_cmd(iostat_list_cmd)['stdout'].split('\n')
    iostat_list = [x.strip() for x in iostat_list if x.strip()]  # 去除空行
    discovery_data = {"data": []}
    for item in iostat_list:
        discovery_data["data"].append({"{#IO_NAME}": item})
    
    # 获取本机IP
    senderhostname = execute_cmd(zbx_ip)['stdout'].strip()
    output_data = "{0} {1} {2}".format(senderhostname, zbx_key_discovery, json.dumps(discovery_data))
    print(output_data)  # 输出到标准输出，可以用来检查格式是否正确
    
    # 写入临时文件
    with open(tmp_file_discovery, 'w') as f:
        f.write(output_data)

    # 发送数据给 Zabbix
    sender_data_ret = execute_cmd('{0} -c {1} -i {2}'.format(zbx_sender_bin, zbx_conf_path, tmp_file_discovery))

    # 当命令执行成功，并且找到"failed: 0"
    if sender_data_ret['status'] == 0:
        os.remove(tmp_file_discovery)  # 删除临时文件
    else:
        print(sender_data_ret['stdout'])  # 输出错误信息


def send_iostat_status():
    # 获取本机IP
    senderhostname = execute_cmd(zbx_ip)['stdout'].strip()
    # 获取状态
    iostat_status = execute_cmd(iostat_status_cmd)['stdout'].split('\n')
    results = {}
    for line in iostat_status:
        if line.strip():
            device, value = line.strip().split()
            results[device] = value
    if results:
        with open(tmp_file_status, 'w') as f:
            for device, value in results.items():
                f.write("{0} zbx.iostat.status[{1}] {2}\n".format(senderhostname, device, value))
        # 发送数据给zabbix
        sender_data_ret = execute_cmd('{0} -c {1} -i {2}'.format(zbx_sender_bin, zbx_conf_path, tmp_file_status))
        # 当命令执行成功，并且找到"failed: 0"
        if sender_data_ret['status'] == 0:
            os.remove(tmp_file_status)  # 删除临时文件
        else:
            print(sender_data_ret['stdout'])  # 输出错误信息


if __name__ == '__main__':
    if len(sys.argv) == 2 and sys.argv[1] == "iostat_discovery":
        file_lock()
        send_iostat_discovery()
    elif len(sys.argv) == 2 and sys.argv[1] == "iostat_status":
        file_lock()
        send_iostat_status()
    else:
        print("请输入: python iostat_status.py iostat_discovery or iostat_status")
