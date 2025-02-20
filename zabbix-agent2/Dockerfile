##########################################
#         构建基础镜像                    #
##########################################
#
# zabbix版本号
ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}.9
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-pgsql:${ZBX_VERSION}

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} as builder

# 指定创建的基础镜像
FROM ubuntu:jammy

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 环境设置
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND

# GO环境变量
ARG GO_VERSION=1.24.0
ENV GO_VERSION=$GO_VERSION
ARG GOROOT=/opt/go
ENV GOROOT=$GOROOT
ARG GOPATH=/opt/golang
ENV GOPATH=$GOPATH

# zabbix版本号
ARG MAJOR_VERSION
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    ZABBIX_USER_HOME_DIR="/usr/local/zabbix" \
    ZABBIX_CONF_DIR="/usr/local/zabbix/etc"

# 安装依赖包
ARG PKG_DEPS="\
    zsh \
    bash \
    bash-doc \
    bash-completion \
    dnsutils \
    iproute2 \
    net-tools \
    fping \
    sysstat \
    ncat \
    git \
    sudo \
    dmidecode \
    util-linux \
    vim \
    jq \
    lrzsz \
    tzdata \
    curl \
    wget \
    axel \
    lsof \
    zip \
    unzip \
    tar \
    rsync \
    iputils-ping \
    telnet \
    procps \
    libaio1 \
    numactl \
    xz-utils \
    gnupg2 \
    psmisc \
    libmecab2 \
    debsums \
    locales \
    iptables \
    python2 \
    python3 \
    python3-dev \
    python3-pip \
    mysql-client \
    postgresql-client \
    snmp-mibs-downloader \
    language-pack-zh-hans \
    fonts-droid-fallback \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

ARG INSTALL_PKGS="\
    tzdata \
    smartmontools \
    libssl3 \
    libcurl4 \
    libpcre2-8-0 \
    libldap-2.4"
ENV INSTALL_PKGS=$INSTALL_PKGS

# ***** 安装依赖 *****
RUN --mount=type=cache,target=/var/cache/apt/,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/,sharing=locked \
   set -eux && \
   # 更新源地址
   sed -i s@http://*.*ubuntu.com@https://mirrors.aliyun.com@g /etc/apt/sources.list && \
   sed -i 's?# deb-src?deb-src?g' /etc/apt/sources.list && \
   # 解决证书认证失败问题
   touch /etc/apt/apt.conf.d/99verify-peer.conf && echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }" && \
   # 更新系统软件
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   # 安装依赖包
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $PKG_DEPS $INSTALL_PKGS --option=Dpkg::Options::=--force-confdef && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoremove --purge && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoclean && \
   rm -rf /var/lib/apt/lists/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   locale-gen zh_CN.UTF-8 && localedef -f UTF-8 -i zh_CN zh_CN.UTF-8 && locale-gen && \
   /bin/zsh

# ***** 安装golang *****
RUN set -eux && \
    wget --no-check-certificate https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go${GO_VERSION}.linux-amd64.tar.gz && \
    cd /tmp/ && tar zxvf go${GO_VERSION}.linux-amd64.tar.gz -C /opt && \
    export GOROOT=/opt/go && \
    export GOPATH=/opt/golang && \
    export PATH=$PATH:$GOROOT/bin:$GOPATH/bin && \
    mkdir -pv $GOPATH/bin && \
    ln -sfd /opt/go/bin/* /usr/bin/

# ***** 升级 python3 版本 *****
RUN set -eux && \
    # update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    pip3 config set global.index-url http://mirrors.aliyun.com/pypi/simple/ && \
    pip3 config set install.trusted-host mirrors.aliyun.com && \
    wget --no-check-certificate https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /tmp/get-pip.py && \
    python2 /tmp/get-pip.py && rm -rf /tmp/get-pip.py && \
    wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py && \
    python3 /tmp/get-pip.py && rm -rf /tmp/get-pip.py && \
    pip3 install --upgrade pip setuptools wheel pycryptodome lxml cython beautifulsoup4 requests && \
    rm -r /root/.cache && rm -rf /tmp/*

# ***** 创建zabbix用户和相关目录 *****
RUN set -eux && \
    addgroup --system --gid 1995 zabbix && \
    adduser --system \
            --gecos "Zabbix monitoring system" \
            --disabled-password \
            --uid 1997 \
            --ingroup zabbix \
            --shell /sbin/nologin \
            --home ${ZABBIX_USER_HOME_DIR} \
                            zabbix && \
    adduser zabbix root && \
    adduser zabbix dialout && \
    mkdir -p ${ZABBIX_CONF_DIR} && \
    mkdir -p ${ZABBIX_CONF_DIR}/zabbix_agentd.d && \
    mkdir -p ${ZABBIX_CONF_DIR}/zabbix_agent2.d && \
    mkdir -p ${ZABBIX_CONF_DIR}/zabbix_agentd.conf.d && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/enc && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/enc_internal && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/buffer && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/scripts && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/user_scripts && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/tools && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/modules && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/buffer

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 10050/TCP 31999/TCP

# ***** 工作目录 *****
WORKDIR ${ZABBIX_USER_HOME_DIR}

# 拷贝文件
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}-output/agent2/sbin/", "/usr/sbin/"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}-output/general/bin/*", "/usr/bin/"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}-output/agent2/conf/", "${ZABBIX_CONF_DIR}/"]
COPY ["./zabbix-agent2/docker-entrypoint.sh", "/usr/bin/"]
COPY ["./zabbix-agent2/sbin/zabbix-agent2-plugin/", "/usr/sbin/zabbix-agent2-plugin/"]
COPY ["./zabbix-agent2/tools/", "${ZABBIX_USER_HOME_DIR}/tools/"]
COPY ["./zabbix-agent2/zabbix_agent2.d/", "${ZABBIX_CONF_DIR}/zabbix_agent2.d/"]

# ***** 创建zabbix目录授权 *****
RUN set -eux && \
    sed -i 's/^Defaults.*.requiretty/#Defaults    requiretty/' /etc/sudoers && \
    sed -i '$a\zabbix  ALL=(ALL)  NOPASSWD:ALL' /etc/sudoers && \
    cp -rf /root/.oh-my-zsh ${ZABBIX_USER_HOME_DIR}/.oh-my-zsh && \
    cp -rf /root/.zshrc ${ZABBIX_USER_HOME_DIR}/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#${ZABBIX_USER_HOME_DIR}/.oh-my-zsh#' ${ZABBIX_USER_HOME_DIR}/.zshrc && \
    chmod a+x /usr/bin/docker-entrypoint.sh /usr/sbin/zabbix_agent2 /usr/bin/zabbix_get /usr/bin/zabbix_sender && \
    chown --quiet -R zabbix:root ${ZABBIX_USER_HOME_DIR} /usr/sbin/zabbix-agent2-plugin/ && \
    chgrp -R 0 ${ZABBIX_USER_HOME_DIR} /usr/sbin/zabbix-agent2-plugin/ && \
    chmod -R g=u ${ZABBIX_USER_HOME_DIR} /usr/sbin/zabbix-agent2-plugin/ && \
    rm -rf /var/lib/apt/lists/* && \
    /usr/sbin/zabbix_agent2 -V

# ***** 入口 *****
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

# ***** 运行用户 *****
USER 1997

# ***** 执行命令 *****
CMD ["/usr/sbin/zabbix_agent2", "--foreground", "-c", "/usr/local/zabbix/etc/zabbix_agent2.conf"]
