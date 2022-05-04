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
ENV MAJOR_VERSION=$MAJOR_VERSION
ARG ZBX_VERSION=${MAJOR_VERSION}.4
ENV ZBX_VERSION=$ZBX_VERSION

# 环境
ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} \
    PATH=/usr/lib/jvm/default-jvm/bin:$PATH \
    JAVA_HOME=/usr/lib/jvm/default-jvm

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
    autoconf \
    automake \
    coreutils \
    curl-dev \
    libevent-dev \
    libssh-dev \
    sqlite-dev \
    libmodbus-dev \
    libxml2-dev \
    mysql-dev \
    net-snmp-dev \
    openipmi-dev \
    openldap-dev \
    openssl-dev \
    pcre-dev \
    postgresql-dev \
    openjdk8 \
    gettext \
    git \
    g++ \
    go \
    make \
    openjdk8-jre-base \
    unixodbc-dev"
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
    /bin/zsh