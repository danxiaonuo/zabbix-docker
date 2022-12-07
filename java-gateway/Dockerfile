##########################################
#         构建基础镜像                    #
##########################################
#
# zabbix版本号
ARG MAJOR_VERSION=6.0
ARG ZBX_VERSION=${MAJOR_VERSION}.6
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
    go \
    jq \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

ARG INSTALL_PKGS="openjdk8-jre-base"
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
    mkdir -p /usr/local/zabbix/etc

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 10053/TCP

# ***** 工作目录 *****
WORKDIR /usr/local/zabbix

# 拷贝文件
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_java/bin", "/usr/sbin/zabbix_java/bin"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/src/zabbix_java/lib", "/usr/sbin/zabbix_java/lib"]
COPY ["./java-gateway/docker-entrypoint.sh", "/usr/bin/"]
COPY ["./java-gateway/conf/usr/sbin/zabbix_java_gateway", "/usr/sbin/"]

# ***** 创建zabbix目录授权 *****
RUN set -eux && \
    cp -rf /root/.oh-my-zsh /usr/local/zabbix/.oh-my-zsh && \
    cp -rf /root/.zshrc /usr/local/zabbix/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/usr/local/zabbix/.oh-my-zsh#' /usr/local/zabbix/.zshrc && \
    mkdir -p /usr/sbin/zabbix_java/ && \
    mkdir -p /usr/sbin/zabbix_java/ext_lib/ && \
    rm -rf /usr/sbin/zabbix_java/lib/logback.xml && \
    mv /usr/sbin/zabbix_java/lib/logback-console.xml /usr/local/zabbix/etc/zabbix_java_gateway_logback.xml && \
    chmod a+x /usr/bin/docker-entrypoint.sh /usr/sbin/zabbix_java_gateway && \
    chown --quiet -R zabbix:root /usr/local/zabbix/ /usr/sbin/zabbix_java/ && \
    chgrp -R 0 /usr/local/zabbix/ /usr/sbin/zabbix_java/ && \
    chmod -R g=u /usr/local/zabbix/ /usr/sbin/zabbix_java/ && \
    rm -rf /var/cache/apk/*

# ***** 入口 *****
ENTRYPOINT ["docker-entrypoint.sh"]

# ***** 运行用户 *****
USER 1997

# ***** 执行命令 *****
CMD ["/usr/sbin/zabbix_java_gateway"]
