#!/bin/bash
docker build . -t danxiaonuo/zabbix-build-base:latest -f build-base/Dockerfile --force-rm --no-cache --network=host
docker build . -t danxiaonuo/zabbix-build-mysql:latest -f build-mysql/Dockerfile --force-rm --no-cache --network=host
docker build . -t danxiaonuo/zabbix-server:latest -f zabbix-server/Dockerfile --force-rm --no-cache --network=host