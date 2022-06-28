##########################################
#         构建基础镜像                    #
##########################################
#
#
# zabbix版本号
ARG MAJOR_VERSION=6.0
ARG ZBX_VERSION=${MAJOR_VERSION}.6
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-mysql:latest
ARG BUILD_NGINX_IMAGE=danxiaonuo/nginx:latest
ARG BUILD_PHP_IMAGE=danxiaonuo/php:latest

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} as builder
FROM ${BUILD_NGINX_IMAGE} as nginx
FROM ${BUILD_PHP_IMAGE} as php

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
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

# NGINX工作目录
ARG NGINX_DIR=/data/nginx
ENV NGINX_DIR=$NGINX_DIR
# NGINX环境变量
ARG PATH=/data/nginx/sbin:$PATH
ENV PATH=$PATH

# luajit2
# https://github.com/openresty/luajit2
ARG LUAJIT_VERSION=2.1-20211210
ENV LUAJIT_VERSION=$LUAJIT_VERSION
ARG LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_LIB=$LUAJIT_LIB
ARG LUAJIT_INC=/usr/local/include/luajit-2.1
ENV LUAJIT_INC=$LUAJIT_INC
ARG LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH

# lua-resty-core
# https://github.com/openresty/lua-resty-core
ARG LUA_RESTY_CORE_VERSION=0.1.22
ENV LUA_RESTY_CORE_VERSION=$LUA_RESTY_CORE_VERSION
ARG LUA_LIB_DIR=/usr/local/share/lua/5.1
ENV LUA_LIB_DIR=$LUA_LIB_DIR

# PHP工作目录
ARG PHP_DIR=/data/php
ENV PHP_DIR=$PHP_DIR
# 环境变量
ARG PATH=/data/php/bin:$PATH
ENV PATH=$PATH

ARG PKG_DEPS="\
    mariadb-client \
    mariadb-connector-c \
    supervisor \
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
    ca-certificates \
    geoip-dev \
    openssl-dev \
    pcre-dev \
    zlib-dev"
ENV PKG_DEPS=$PKG_DEPS

ARG NGINX_BUILD_DEPS="\
    # NGINX
    alpine-sdk \
    bash \
    findutils \
    gcc \
    gd-dev \
    geoip-dev \
    libc-dev \
    libedit-dev \
    libxslt-dev \
    linux-headers \
    make \
    mercurial \
    openssl-dev \
    pcre-dev \
    perl-dev \
    zlib-dev"
ENV NGINX_BUILD_DEPS=$NGINX_BUILD_DEPS

ARG PHP_BUILD_DEPS="\
    ca-certificates \
    openssl \
    tar \
    xz \
    bison \
    readline \
    readline-dev \
    libxslt \
    libxslt-dev \
    libxml2 \
    libxml2-dev \
    openssl \
    openssl-dev \
    bzip2 \
    bzip2-dev \
    curl \
    curl-dev \
    freetype \
    freetype-dev \
    libpng \
    libpng-dev \
    libwebp \
    libwebp-dev \
    libjpeg-turbo \
    libjpeg-turbo-dev \
    libsodium \
    libsodium-dev \
    argon2-dev \
    coreutils \
    linux-headers \
    krb5-dev \
    pcre2-dev \
    sqlite-dev \
    gettext-dev \
    gmp-dev \
    openssl-dev \
    c-client \
    imap-dev \
    icu-dev \
    ldb-dev \
    libldap \
    openldap-dev \
    oniguruma-dev \
    tidyhtml-dev \
    libzip-dev"
ENV PHP_BUILD_DEPS=$PHP_BUILD_DEPS

# ***** 安装依赖 *****
RUN set -eux && \
   # 修改源地址
   sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
   # 更新源地址并更新系统软件
   apk update && apk upgrade && \
   # 安装依赖包
   apk add --no-cache --clean-protected $PKG_DEPS $PHP_BUILD_DEPS && \
   rm -rf /var/cache/apk/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   mkdir -p /www/zabbix /data && \
   /bin/zsh

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
COPY --from=nginx /usr/local/lib /usr/local/lib
COPY --from=nginx /usr/local/share/lua /usr/local/share/lua
COPY --from=nginx /data/nginx /data/nginx
COPY --from=php /data/php /data/php

# ***** 删除配置文件 *****
RUN set -eux && \
    cd /www/zabbix/ && \
    rm -f conf/zabbix.conf.php conf/maintenance.inc.php conf/zabbix.conf.php.example assets/fonts/DejaVuSans.ttf && \
    rm -rf tests && \
    rm -f locale/add_new_language.sh locale/update_po.sh locale/make_mo.sh && \
    find /www/zabbix/locale -name '*.po' | xargs rm -f && \
    find /www/zabbix/locale -name '*.sh' | xargs rm -f

# 拷贝文件
COPY ["./web-nginx/docker-entrypoint.sh", "/usr/bin/"]
COPY ["./web-nginx/conf/etc/zabbix/web/", "/www/zabbix/conf/"]
COPY ["./web-nginx/assets/fonts/DejaVuSans.ttf", "/www/zabbix/assets/fonts/DejaVuSans.ttf"]
COPY ["./web-nginx/conf/nginx/php.conf", "/data/nginx/conf/php.conf"]
COPY ["./web-nginx/conf/nginx/vhost/default.conf", "/data/nginx/conf/vhost/default.conf"]
COPY ["./web-nginx/conf/supervisor", "/etc/supervisor"]

# 安装相关依赖
RUN set -eux && \
    apk add --no-cache --virtual .gettext gettext && \
    mv /usr/bin/envsubst /tmp/ && \
    runDeps="$( \
        scanelf --needed --nobanner ${NGINX_DIR}/sbin/nginx ${NGINX_DIR}/modules/*.so ${LUAJIT_LIB}/*.so /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" && \
    apk add --no-cache --virtual .$NGINX_BUILD_DEPS $runDeps && \
    apk del .gettext && \
    mv /tmp/envsubst /usr/local/bin/

# ***** 检查依赖并授权 *****
RUN set -eux && \
    # 创建用户和用户组
    addgroup -g 32548 -S nginx && \
    adduser -S -D -H -u 32548 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx && \
    chmod a+x /usr/bin/docker-entrypoint.sh && \
    chown --quiet -R nginx:nginx /www/zabbix && \
    chmod -R 775 /www/zabbix/ && \
    cp -rf /root/.oh-my-zsh /www/zabbix/.oh-my-zsh && \
    cp -rf /root/.zshrc /www/zabbix/.zshrc && \
    sed -i '5s#/root/.oh-my-zsh#/www/zabbix/.oh-my-zsh#' /www/zabbix/.zshrc && \
    ln -sf /dev/stdout /data/nginx/logs/access.log && \
    ln -sf /dev/stderr /data/nginx/logs/error.log && \
    # smoke test
    # ##############################################################################
    ln -sf ${NGINX_DIR}/sbin/* /usr/sbin/ && \
    ln -sf ${PHP_DIR}/bin/* /usr/bin/ && \
    ln -sf ${PHP_DIR}/sbin/* /usr/sbin/ && \
    nginx -V && \
    php-fpm -v && \
    nginx -t && \
    php-fpm -t && \
    rm -rf /var/cache/apk/*

# ***** 入口 *****
ENTRYPOINT ["docker-entrypoint.sh"]

# 自动检测服务是否可用
HEALTHCHECK --interval=30s --timeout=3s CMD curl --fail http://localhost/ || exit 1