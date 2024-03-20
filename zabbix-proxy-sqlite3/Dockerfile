##########################################
#         构建基础镜像                    #
##########################################
#
# zabbix版本号
ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-sqlite3:${ZBX_VERSION}

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} as builder

# 指定创建的基础镜像
ARG BASE_IMAGE_TAG=jammy
ARG BUILD_IMAGE=ubuntu:${BASE_IMAGE_TAG}
FROM ${BUILD_IMAGE}

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
ARG GO_VERSION=1.22.1
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
    MIBDIRS=/var/lib/mibs/ietf:/var/lib/mibs/iana:/usr/share/snmp/mibs:/var/lib/zabbix/mibs MIBS=+ALL \
    NMAP_PRIVILEGED=""

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
    bash \
    traceroute \
    nmap \
    ca-certificates \
    fping \
    libcurl4 \
    libevent-2.1 \
    libevent-pthreads-2.1 \
    libopenipmi0 \
    libpcre2-8-0 \
    libsnmp40 \
    libsqlite3-0 \
    libssh-4 \
    libssl3 \
    libxml2 \
    snmp-mibs-downloader \
    unixodbc"
ENV INSTALL_PKGS=$INSTALL_PKGS

# ***** 安装依赖 *****
RUN --mount=type=cache,target=/var/lib/apt/,sharing=locked \
   set -eux && \
   # 更新源地址
   sed -i s@http://*.*ubuntu.com@https://mirrors.aliyun.com@g /etc/apt/sources.list && \
   sed -i 's?# deb-src?deb-src?g' /etc/apt/sources.list && \
   # 解决证书认证失败问题
   touch /etc/apt/apt.conf.d/99verify-peer.conf && echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }" && \
   # 更新系统软件
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   # 安装依赖包
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $PKG_DEPS $INSTALL_PKGS && \
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

# ***** 升级 setuptools 版本 *****
RUN set -eux && \
    pip3 config set global.index-url http://mirrors.aliyun.com/pypi/simple/ && \
    pip3 config set install.trusted-host mirrors.aliyun.com && \
    python3 -m ensurepip && \
    rm -r /usr/lib/python*/ensurepip && \
    pip3 install --upgrade pip setuptools wheel pycryptodome lxml cython beautifulsoup4 requests && \
    if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi && \
    if [[ ! -e /usr/bin/python ]]; then ln -sf /usr/bin/python3 /usr/bin/python; fi && \
    wget --no-check-certificate https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /tmp/get-pip.py && \
    python2 /tmp/get-pip.py && \
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
            --home /usr/local/zabbix/ \
                            zabbix && \
    adduser zabbix root && \
    adduser zabbix dialout && \
    chgrp zabbix /usr/bin/nmap && \
    setcap cap_net_raw+eip /usr/bin/nmap && \
    mkdir -p /usr/local/zabbix/db_data && \
    mkdir -p /usr/local/zabbix/etc/zabbix_proxy.conf.d && \
    mkdir -p /usr/local/zabbix/alertscripts && \
    mkdir -p /usr/local/zabbix/enc && \
    mkdir -p /usr/local/zabbix/export && \
    mkdir -p /usr/local/zabbix/scripts && \
    mkdir -p /usr/local/zabbix/externalscripts && \
    mkdir -p /usr/local/zabbix/mibs && \
    mkdir -p /usr/local/zabbix/modules && \
    mkdir -p /usr/local/zabbix/snmptraps && \
    mkdir -p /usr/local/zabbix/ssh_keys && \
    mkdir -p /usr/local/zabbix/ssl && \
    mkdir -p /usr/local/zabbix/ssl/certs && \
    mkdir -p /usr/local/zabbix/ssl/keys && \
    mkdir -p /usr/local/zabbix/ssl/ssl_ca && \
    mkdir -p /usr/local/zabbix/share/doc/zabbix-proxy-mysql-mysql

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 16165/TCP

# ***** 工作目录 *****
WORKDIR /usr/local/zabbix

# ***** 挂载目录 *****
VOLUME ["/usr/local/zabbix/snmptraps", "/usr/local/zabbix/export"]

# 拷贝文件
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_proxy/zabbix_proxy", "/usr/sbin/zabbix_proxy"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_get/zabbix_get", "/usr/bin/zabbix_get"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_sender/zabbix_sender", "/usr/bin/zabbix_sender"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/conf/zabbix_proxy.conf", "/usr/local/zabbix/etc/zabbix_proxy.conf"]
COPY ["./zabbix-proxy-sqlite3/docker-entrypoint.sh", "/usr/bin/"]

# ***** 创建zabbix目录授权 *****
RUN set -eux && \
    sed -i '$a\zabbix  ALL=(ALL)  NOPASSWD:ALL' /etc/sudoers && \
    cp -rf /root/.oh-my-zsh /usr/local/zabbix/.oh-my-zsh && \
    cp -rf /root/.zshrc /usr/local/zabbix/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/usr/local/zabbix/.oh-my-zsh#' /usr/local/zabbix/.zshrc && \
    chmod a+x /usr/bin/docker-entrypoint.sh /usr/sbin/zabbix_proxy /usr/bin/zabbix_get /usr/bin/zabbix_sender && \
    chown --quiet -R zabbix:root /usr/local/zabbix/ && \
    chgrp -R 0 /usr/local/zabbix/ && \
    chmod -R g=u /usr/local/zabbix/ && \
    rm -rf /var/lib/apt/lists/*

# ***** 入口 *****
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

# ***** 运行用户 *****
USER 1997

# ***** 执行命令 *****
CMD ["/usr/sbin/zabbix_proxy", "--foreground", "-c", "/usr/local/zabbix/etc/zabbix_proxy.conf"]
