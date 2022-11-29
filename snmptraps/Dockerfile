##########################################
#         构建基础镜像                    #
##########################################
#
# 指定创建的基础镜像
FROM alpine:latest

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# zabbix版本号
ARG MAJOR_VERSION=6.0
ARG ZBX_VERSION=${MAJOR_VERSION}.11
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    MIBDIRS=/usr/share/snmp/mibs:/usr/local/zabbix/mibs MIBS=+ALL \
    ZBX_SNMP_TRAP_DATE_FORMAT=+%Y%m%d.%H%M%S ZBX_SNMP_TRAP_FORMAT="\n"
 
# 安装依赖包
ARG PKG_DEPS="\
    zsh \
    bash \
    bash-doc \
    bash-completion \
    bind-tools \
    iproute2 \
    git \
    vim \
    tzdata \
    curl \
    wget \
    lsof \
    tar \
    zip \
    unzip \
    jq \
    sudo \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

ARG INSTALL_PKGS="\
    net-snmp \
    net-snmp-tools"
ENV INSTALL_PKGS=$INSTALL_PKGS

# ***** 安装依赖 *****
RUN set -eux && \
    # 修改源地址
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    # 更新源地址并更新系统软件
    apk update && apk upgrade && \
    # 安装依赖包
    apk add --no-cache --clean-protected $PKG_DEPS $INSTALL_PKGS && \
    rm -rf /var/cache/apk/* && \
    # 更新时区
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    # 更新时间
    echo ${TZ} > /etc/timezone && \
    # 更改为zsh
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
    sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
    sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
    sed -i '$a\zabbix  ALL=(ALL)  NOPASSWD:ALL' /etc/sudoers && \
    /bin/zsh

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
    mkdir -p /usr/local/zabbix && \
    mkdir -p /usr/local/zabbix/mibs && \
    mkdir -p /usr/local/zabbix/snmptraps
 
# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 1162/UDP

# ***** 工作目录 *****
WORKDIR /usr/local/zabbix/snmptraps

# ***** 挂载目录 *****
VOLUME ["/usr/local/zabbix/snmptraps"]

# 拷贝文件
COPY ["./snmptraps/conf/etc/logrotate.d/zabbix_snmptraps", "/etc/logrotate.d/"]
COPY ["./snmptraps/conf/etc/snmp/snmptrapd.conf", "/etc/snmp/"]
COPY ["./snmptraps/conf/usr/sbin/zabbix_trap_handler.sh", "/usr/sbin/"]

# ***** 创建zabbix目录授权 *****
RUN set -eux && \
    cp -rf /root/.oh-my-zsh /usr/local/zabbix/.oh-my-zsh && \
    cp -rf /root/.zshrc /usr/local/zabbix/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/usr/local/zabbix/.oh-my-zsh#' /usr/local/zabbix/.zshrc && \
    chmod a+x /usr/sbin/snmptrapd && \
    chown --quiet -R zabbix:root /etc/snmp/ /usr/local/zabbix/ /var/tmp/ /var/run/ && \
    chgrp -R 0 /etc/snmp/ /usr/local/zabbix/ /var/tmp/ /var/run/ && \
    chmod -R g=u /etc/snmp/ /usr/local/zabbix/ /var/tmp/ /var/run/ && \
    rm -rf /var/cache/apk/*
  
 # ***** 运行用户 *****
USER 1997

# ***** 执行命令 *****
CMD ["/usr/sbin/snmptrapd", "-n", "-C", "-c", "/etc/snmp/snmptrapd.conf", "-Lo", "-A"]
