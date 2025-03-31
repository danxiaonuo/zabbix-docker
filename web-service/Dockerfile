##########################################
#         构建基础镜像                    #
##########################################
#
# 指定创建的基础镜像
ARG OS_BASE_IMAGE=ubuntu:jammy
# zabbix版本号
ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}.11
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-pgsql:${ZBX_VERSION}

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} AS builder

# 指定创建的基础镜像
FROM ${OS_BASE_IMAGE}

# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 环境设置
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND

# zabbix版本号
ARG MAJOR_VERSION
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    ZABBIX_USER_HOME_DIR="/usr/local/zabbix" \
    ZABBIX_CONF_DIR="/usr/local/zabbix/etc"

LABEL org.opencontainers.image.authors="danxiaonuo" \
      org.opencontainers.image.vendor="danxiaonuo" \
      org.opencontainers.image.version="${ZBX_VERSION}"

# 安装依赖包
ARG PKG_DEPS="\
    zsh \
    bash \
    bash-doc \
    bash-completion \
    dnsutils \
    iproute2 \
    net-tools \
    sysstat \
    ncat \
    git \
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
    python3 \
    python3-dev \
    python3-pip \
    gnupg \
    language-pack-zh-hans \
    fonts-droid-fallback \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

ARG INSTALL_PKGS="\
    ca-certificates \
    chromium \
    chromium-sandbox"
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
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $PKG_DEPS --option=Dpkg::Options::=--force-confdef && \
   gpg --keyserver keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9 && \
   gpg -o /etc/apt/keyrings/debian.gpg --export 0E98404D386FA1D9 && \
   echo "deb [signed-by=/etc/apt/keyrings/debian.gpg] http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list.d/debian.list && \
   echo "deb [signed-by=/etc/apt/keyrings/debian.gpg] http://deb.debian.org/debian bullseye-updates main" >> /etc/apt/sources.list.d/debian.list && \
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $INSTALL_PKGS --option=Dpkg::Options::=--force-confdef && \
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
    mkdir -p ${ZABBIX_CONF_DIR}

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 10053/TCP

# ***** 工作目录 *****
WORKDIR ${ZABBIX_USER_HOME_DIR}

# 拷贝文件
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}-output/web_service/sbin/zabbix_web_service", "/usr/sbin/zabbix_web_service"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}-output/web_service/conf/", "${ZABBIX_CONF_DIR}/"]
COPY ["./web-service/conf/etc/apt/preferences.d/chromium.pref", "/etc/apt/preferences.d/chromium.pref"]
COPY ["./web-service/docker-entrypoint.sh", "/usr/bin/"]

# ***** 创建zabbix目录授权 *****
RUN set -eux && \
    cp -rf /root/.oh-my-zsh ${ZABBIX_USER_HOME_DIR}/.oh-my-zsh && \
    cp -rf /root/.zshrc ${ZABBIX_USER_HOME_DIR}/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/usr/local/zabbix/.oh-my-zsh#' ${ZABBIX_USER_HOME_DIR}/.zshrc && \
    chmod a+x /usr/bin/docker-entrypoint.sh /usr/sbin/zabbix_web_service && \
    chown --quiet -R zabbix:root ${ZABBIX_USER_HOME_DIR} && \
    chgrp -R 0 ${ZABBIX_USER_HOME_DIR} && \
    chmod -R g=u ${ZABBIX_USER_HOME_DIR} && \
    rm -rf /var/lib/apt/lists/* && \
    /usr/sbin/zabbix_web_service -V

# ***** 入口 *****
ENTRYPOINT ["docker-entrypoint.sh"]

# ***** 运行用户 *****
USER 1997

# ***** 执行命令 *****
CMD ["/usr/sbin/zabbix_web_service", "-c", "/usr/local/zabbix/etc/zabbix_web_service.conf"]
