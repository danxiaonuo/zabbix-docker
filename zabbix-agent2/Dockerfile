##########################################
#         构建基础镜像                    #
##########################################
#
# zabbix版本号
ARG MAJOR_VERSION=6.0
ARG ZBX_VERSION=${MAJOR_VERSION}
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-mysql:latest

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} as builder

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
ARG MAJOR_VERSION
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    MIBDIRS=/usr/share/snmp/mibs:/usr/local/zabbix/mibs MIBS=+ALL

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
    sysstat \
    sudo \
    python2 \
    python2-dev \
    python3 \
    python3-dev \
    go \
    jq \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

ARG INSTALL_PKGS="\
    tini \
    fping \
    iputils \
    mariadb-client \
    mariadb-connector-c \
    net-snmp-agent-libs \
    net-snmp-tools \
    openipmi-libs \
    pcre2 \
    unixodbc"
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

# ***** 升级 setuptools 版本 *****
RUN set -eux && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --upgrade pip setuptools wheel pycryptodome lxml cython beautifulsoup4 && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi && \
    if [[ ! -e /usr/bin/python ]]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    rm -r /root/.cache

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
    mkdir -p /usr/local/zabbix/etc/zabbix_agentd.conf.d && \
    mkdir -p /usr/local/zabbix/enc && \
    mkdir -p /usr/local/zabbix/export && \
    mkdir -p /usr/local/zabbix/scripts && \
    mkdir -p /usr/local/zabbix/modules && \
    mkdir -p /usr/local/zabbix/buffer

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 10050/TCP 31999/TCP

# ***** 工作目录 *****
WORKDIR /usr/local/zabbix

# 拷贝文件
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/go/bin/zabbix_agent2", "/usr/sbin/zabbix_agent2"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_get/zabbix_get", "/usr/bin/zabbix_get"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_sender/zabbix_sender", "/usr/bin/zabbix_sender"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/go/conf/zabbix_agent2.conf", "/usr/local/zabbix/etc/zabbix_agent2.conf"]
COPY ["./zabbix-agent2/docker-entrypoint.sh", "/usr/bin/"]

# ***** 创建zabbix目录授权 *****
RUN set -eux && \
    cp -rf /root/.oh-my-zsh /usr/local/zabbix/.oh-my-zsh && \
    cp -rf /root/.zshrc /usr/local/zabbix/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/usr/local/zabbix/.oh-my-zsh#' /usr/local/zabbix/.zshrc && \
    chmod a+x /usr/bin/docker-entrypoint.sh /usr/sbin/zabbix_agent2 /usr/bin/zabbix_get /usr/bin/zabbix_sender && \
    chown --quiet -R zabbix:root /usr/local/zabbix/ && \
    chgrp -R 0 /usr/local/zabbix/ && \
    chmod -R g=u /usr/local/zabbix/ && \
    ln -sf /usr/sbin/fping /usr/sbin/fping6 && \
    rm -rf /var/cache/apk/*

# ***** 入口 *****
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/docker-entrypoint.sh"]

# ***** 运行用户 *****
USER 1997

# ***** 执行命令 *****
CMD ["/usr/sbin/zabbix_agent2", "--foreground", "-c", "/usr/local/zabbix/etc/zabbix_agent2.conf"]
