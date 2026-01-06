##########################################
#         构建基础镜像                    #
##########################################
#
# 指定创建的基础镜像
ARG OS_BASE_IMAGE=ubuntu:jammy
# zabbix版本号
ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}.22
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-mysql:${ZBX_VERSION}
ARG BUILD_NGINX_IMAGE=danxiaonuo/nginx:latest
ARG BUILD_PHP_IMAGE=danxiaonuo/php:latest

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} AS builder
FROM ${BUILD_NGINX_IMAGE} AS nginx
FROM ${BUILD_PHP_IMAGE} AS php

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
    ZABBIX_WWW_ROOT="/www/zabbix"

# NGINX工作目录
ARG NGINX_DIR=/data/nginx
ENV NGINX_DIR=$NGINX_DIR
# NGINX环境变量
ARG PATH=/data/nginx/sbin:$PATH
ENV PATH=$PATH

# luajit2
# https://github.com/openresty/luajit2
ARG LUAJIT_VERSION=2.1-20250826
ENV LUAJIT_VERSION=$LUAJIT_VERSION
ARG LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_LIB=$LUAJIT_LIB
ARG LUAJIT_INC=/usr/local/include/luajit-2.1
ENV LUAJIT_INC=$LUAJIT_INC
ARG LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH

# lua-resty-core
# https://github.com/openresty/lua-resty-core
ARG LUA_RESTY_CORE_VERSION=0.1.32
ENV LUA_RESTY_CORE_VERSION=$LUA_RESTY_CORE_VERSION
ARG LUA_LIB_DIR=/usr/local/share/lua/5.1
ENV LUA_LIB_DIR=$LUA_LIB_DIR

# PHP工作目录
ARG PHP_DIR=/data/php
ENV PHP_DIR=$PHP_DIR
# 环境变量
ARG PATH=/data/php/bin:$PATH
ENV PATH=$PATH

LABEL org.opencontainers.image.authors="danxiaonuo" \
      org.opencontainers.image.vendor="danxiaonuo" \
      org.opencontainers.image.version="${ZBX_VERSION}"

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
    language-pack-zh-hans \
    fonts-droid-fallback \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    ca-certificates \
    libldap-common \
    mysql-client \
    supervisor"
ENV PKG_DEPS=$PKG_DEPS

ARG NGINX_BUILD_DEPS="\
    libssl-dev \
    zlib1g-dev \
    libpcre3-dev \
    libxml2-dev \
    libxslt1-dev \
    libgd-dev \
    libgeoip-dev"
ENV NGINX_BUILD_DEPS=$NGINX_BUILD_DEPS

ARG PHP_BUILD_DEPS="\
    libxml2 \
    libcurl4 \
    libfreetype6 \
    libjpeg-dev \
    libpng16-16 \
    libgettextpo0 \
    libiconv-hook1 \
    libkrb5-3 \
    libpq5 \
    libmysqlclient21 \
    libssl-dev \
    libpcre3 \
    libpcre2-8-0 \
    libsqlite3-0 \
    libbz2-1.0 \
    libcdb1 \
    libgmp10 \
    libreadline8 \
    libldap2-dev \
    libtidy-dev \
    libzip4 \
    libonig5 \
    libxslt1-dev \
    libc-client-dev \
    libgpgme11 \
    libmecab2 \
    libc-client2007e \
    libmcrypt4 \
    libltdl7 \
    libwebp-dev"
ENV PHP_BUILD_DEPS=$PHP_BUILD_DEPS

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
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $PKG_DEPS $NGINX_BUILD_DEPS $PHP_BUILD_DEPS --option=Dpkg::Options::=--force-confdef && \
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

# ***** 容器信号处理 *****
STOPSIGNAL SIGQUIT

# ***** 监听端口 *****
EXPOSE 80/TCP 443/TCP

# ***** 工作目录 *****
WORKDIR ${ZABBIX_WWW_ROOT}

# ***** 挂载目录 *****
VOLUME ["${ZABBIX_WWW_ROOT}"]

# 拷贝文件
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/ui/", "${ZABBIX_WWW_ROOT}"]
COPY --from=nginx /usr/local/lib /usr/local/lib
COPY --from=nginx /usr/local/share/lua /usr/local/share/lua
COPY --from=nginx ${NGINX_DIR} ${NGINX_DIR}
COPY --from=php ${PHP_DIR} ${PHP_DIR}

# ***** 删除配置文件 *****
RUN set -eux && \
    cd ${ZABBIX_WWW_ROOT} && \
    rm -f conf/zabbix.conf.php conf/maintenance.inc.php conf/zabbix.conf.php.example assets/fonts/DejaVuSans.ttf && \
    rm -rf tests && \
    rm -f locale/add_new_language.sh locale/update_po.sh locale/make_mo.sh && \
    find ${ZABBIX_WWW_ROOT}/locale -name '*.po' | xargs rm -f && \
    find ${ZABBIX_WWW_ROOT}/locale -name '*.sh' | xargs rm -f && \
    mkdir -p /www/certs && chmod -R 775 /www/certs && \
    mkdir -p /var/lib/locales/supported.d/ && rm -f /var/lib/locales/supported.d/local && \
    cat ${ZABBIX_WWW_ROOT}/include/locales.inc.php | grep display | grep true | awk '{$1=$1};1' | \
        cut -d"'" -f 2 | sort | \
        xargs -I '{}' bash -c 'echo "{}.UTF-8 UTF-8" >> /var/lib/locales/supported.d/local' && \
    dpkg-reconfigure locales

# 拷贝文件
COPY ["./web-nginx-mysql/docker-entrypoint.sh", "/usr/bin/"]
COPY ["./web-nginx-mysql/conf/etc/zabbix/web/", "${ZABBIX_WWW_ROOT}/conf/"]
COPY ["./web-nginx-mysql/assets/fonts/DejaVuSans.ttf", "${ZABBIX_WWW_ROOT}/assets/fonts/DejaVuSans.ttf"]
COPY ["./web-nginx-mysql/conf/nginx/php.conf", "${NGINX_DIR}/conf/php.conf"]
COPY ["./web-nginx-mysql/conf/nginx/vhost/default.conf", "${NGINX_DIR}/conf/vhost/default.conf"]
COPY ["./web-nginx-mysql/conf/supervisor", "/etc/supervisor"]

# ***** 检查依赖并授权 *****
RUN set -eux && \
    # 创建用户和用户组
    addgroup --system --quiet nginx && \
    adduser --quiet --system --disabled-login --ingroup nginx --home ${NGINX_DIR} --no-create-home nginx && \
    chmod a+x /usr/bin/docker-entrypoint.sh && \
    chown --quiet -R nginx:nginx ${ZABBIX_WWW_ROOT} && \
    chmod -R 775 ${ZABBIX_WWW_ROOT} && \
    cp -rf /root/.oh-my-zsh ${ZABBIX_WWW_ROOT}/.oh-my-zsh && \
    cp -rf /root/.zshrc ${ZABBIX_WWW_ROOT}/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/www/zabbix/.oh-my-zsh#' ${ZABBIX_WWW_ROOT}/.zshrc && \
    ln -sf /dev/stdout ${NGINX_DIR}/logs/access.log && \
    ln -sf /dev/stderr ${NGINX_DIR}/logs/error.log && \
    # smoke test
    # ##############################################################################
    ln -sf ${NGINX_DIR}/sbin/* /usr/sbin/ && \
    ln -sf ${PHP_DIR}/bin/* /usr/bin/ && \
    ln -sf ${PHP_DIR}/sbin/* /usr/sbin/ && \
    nginx -V && \
    php-fpm -v && \
    nginx -t && \
    php-fpm -t && \
    rm -rf /var/lib/apt/lists/*

# ***** 入口 *****
ENTRYPOINT ["docker-entrypoint.sh"]

# 自动检测服务是否可用
HEALTHCHECK --interval=30s --timeout=3s CMD curl --fail http://localhost/ || exit 1
