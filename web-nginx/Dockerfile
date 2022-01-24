##########################################
#         构建基础镜像                    #
##########################################
#
#
# zabbix版本号
ARG MAJOR_VERSION=6.0
ARG ZBX_VERSION=${MAJOR_VERSION}
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-mysql:latest

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} as builder

# 指定创建的基础镜像
FROM danxiaonuo/nginx:latest

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# zabbix版本号
ARG MAJOR_VERSION
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

# 安装依赖包
ARG PKG_DEPS="\
    mariadb-client \
    mariadb-connector-c"
ENV PKG_DEPS=$PKG_DEPS

# ***** 安装依赖 *****
RUN set -eux && \
    # 更新源地址并更新系统软件
    apk update && \
    # 安装依赖包
    apk add --no-cache --clean-protected $PKG_DEPS && \
    rm -rf /var/cache/apk/*

# ***** 创建zabbix用户和相关目录 *****
RUN set -eux && \
    addgroup --system --gid 1995 zabbix && \
    adduser --system \
            --gecos "Zabbix monitoring system" \
            --disabled-password \
            --uid 1997 \
            --ingroup zabbix \
            --shell /sbin/nologin \
            --home /usr/local/zabbix/ \
                            zabbix && \
    adduser zabbix root && \
    adduser zabbix dialout && \
    mkdir -p /www/zabbix

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 80/TCP 443/TCP

# ***** 工作目录 *****
WORKDIR /www/zabbix

# ***** 挂载目录 *****
VOLUME ["/www/zabbix"]

# 拷贝文件
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/ui/", "/www/zabbix/"]

# ***** 删除配置文件 *****
RUN set -eux && \
    cd /www/zabbix/ && \
    rm -f conf/zabbix.conf.php conf/maintenance.inc.php conf/zabbix.conf.php.example && \
    rm -rf tests && \
    rm -f locale/add_new_language.sh locale/update_po.sh locale/make_mo.sh && \
    find /www/zabbix/locale -name '*.po' | xargs rm -f && \
    find /www/zabbix/locale -name '*.sh' | xargs rm -f

# 拷贝文件
COPY ["./web-nginx/docker-entrypoint.sh", "/usr/bin/"]
COPY ["./web-nginx/conf/etc/zabbix/web/", "/www/zabbix/conf/"]

# ***** 创建zabbix目录授权 *****
RUN set -eux && \
    chmod a+x /usr/bin/docker-entrypoint.sh && \
    chown --quiet -R zabbix:root /www/zabbix && \
    chgrp -R 0 /www/zabbix/ && \
    chmod -R g=u /www/zabbix/ && \
    cp -rf /root/.oh-my-zsh /www/zabbix/.oh-my-zsh && \
    cp -rf /root/.zshrc /www/zabbix/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/www/zabbix/.oh-my-zsh#' /www/zabbix/.zshrc && \
    rm -rf /var/cache/apk/*

# ***** 入口 *****
ENTRYPOINT ["docker-entrypoint.sh"]

# ***** 运行用户 *****
USER 1997

# ***** 执行命令 *****
CMD ["nginx", "-g", "daemon off;"]