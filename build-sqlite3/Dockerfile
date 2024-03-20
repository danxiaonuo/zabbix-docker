##########################################
#         构建基础镜像                    #
##########################################
#
# zabbix版本号
ARG MAJOR_VERSION=7.0
ARG ZBX_VERSION=${MAJOR_VERSION}
ARG BUILD_BASE_IMAGE=danxiaonuo/zabbix-build-base:${ZBX_VERSION}

# 指定创建的基础镜像
FROM ${BUILD_BASE_IMAGE} as builder

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# zabbix版本号
ARG MAJOR_VERSION
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git
ARG GIT_BRANCH=master
ENV MONGODB_PLUGIN_SOURCES=https://git.zabbix.com/scm/ap/mongodb.git MONGODB_PLUGIN_VERSION=master \
    POSTGRESQL_PLUGIN_SOURCES=https://git.zabbix.com/scm/ap/postgresql.git POSTGRESQL_PLUGIN_VERSION=master

# 安装编译
RUN --mount=type=cache,target=/root/.cache/go-build/ \
    --mount=type=cache,target=/opt/golang/ \
    set -eux && \
    cd /tmp/ && \
    git -c advice.detachedHead=false clone ${ZBX_SOURCES} --branch ${GIT_BRANCH} --depth 1 --single-branch /tmp/zabbix-${ZBX_VERSION} && \
    cd /tmp/zabbix-${ZBX_VERSION} && \
    sed -i s#1000#100000#g include/proxy.h && \
    sed -i 's#UINT64_C(2)#UINT64_C(64)#g' src/zabbix_server/server.c && \
    sed -i 's#100}#1000}#g' src/zabbix_server/server.c && \
    sed -i 's#UINT64_C(2)#UINT64_C(64)#g' src/zabbix_proxy/proxy.c && \
    sed -i 's#100}#1000}#g' src/zabbix_proxy/proxy.c && \
    zabbix_revision=`git rev-parse --short HEAD` && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" include/version.h && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" src/go/pkg/version/version.go && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" src/zabbix_java/src/com/zabbix/gateway/GeneralInformation.java && \
    ./bootstrap.sh && \
    export CFLAGS="-fPIC -pie -Wl,-z,relro,-z,now,-z,defs" && \
    export CFLAGS="$CFLAGS -D_FORTIFY_SOURCE=2 -fexceptions -O2 -pipe" && \
    ./configure \
            --prefix=/usr/local/zabbix \
            --enable-agent \
            --enable-agent2 \
            --enable-ipv6 \
            --enable-proxy \
            --with-ldap \
            --with-libcurl \
            --with-libmodbus \
            --with-libpcre2 \
            --with-libxml2 \
            --with-net-snmp \
            --with-openipmi \
            --with-openssl \
            --with-sqlite3 \
            --with-ssh \
            --with-unixodbc \
            --enable-java \
            --silent && \
    make -j"$(nproc)" -s dbschema && \
    make -j"$(nproc)" -s && \
    mkdir /tmp/fonts/ && \
    curl --tlsv1.2 -sSf -L "https://noto-website.storage.googleapis.com/pkgs/NotoSansCJKjp-hinted.zip" -o /tmp/fonts/NotoSansCJKjp-hinted.zip && \
    unzip /tmp/fonts/NotoSansCJKjp-hinted.zip -d /tmp/fonts/ && \
    cp /tmp/fonts/NotoSansCJKjp-Regular.otf /tmp/zabbix-${ZBX_VERSION}/ui/assets/fonts/NotoSansCJKjp-Regular.ttf && \
    cp /tmp/fonts/LICENSE_OFL.txt /tmp/zabbix-${ZBX_VERSION}/ui/assets/fonts/ && \
    rm -f /tmp/zabbix-${ZBX_VERSION}/ui/assets/fonts/DejaVuSans.ttf && \
    sed -i -r "s/(define\(.*_FONT_NAME.*)DejaVuSans/\1NotoSansCJKjp-Regular/" /tmp/zabbix-${ZBX_VERSION}/ui/include/defines.inc.php && \
    rm -rf /tmp/fonts/ && \
    chmod o+r /tmp/zabbix-${ZBX_VERSION}/ui/assets/fonts/* && \
    strip /tmp/zabbix-${ZBX_VERSION}/src/zabbix_agent/zabbix_agentd && \
    strip /tmp/zabbix-${ZBX_VERSION}/src/zabbix_proxy/zabbix_proxy && \
    strip /tmp/zabbix-${ZBX_VERSION}/src/go/bin/zabbix_agent2 && \
    strip /tmp/zabbix-${ZBX_VERSION}/src/zabbix_get/zabbix_get && \
    strip /tmp/zabbix-${ZBX_VERSION}/src/zabbix_sender/zabbix_sender && \
    cd /tmp/ && \
    git -c advice.detachedHead=false clone ${MONGODB_PLUGIN_SOURCES} --branch ${MONGODB_PLUGIN_VERSION} --depth 1 --single-branch /tmp/mongodb_plugin && \
    cd /tmp/mongodb_plugin && \
    make && \
    strip /tmp/mongodb_plugin/zabbix-agent2-plugin-mongodb && \
    cd /tmp/ && \
    git -c advice.detachedHead=false clone ${POSTGRESQL_PLUGIN_SOURCES} --branch ${POSTGRESQL_PLUGIN_VERSION} --depth 1 --single-branch /tmp/postgresql_plugin && \
    cd /tmp/postgresql_plugin && \
    make && \
    strip /tmp/postgresql_plugin/zabbix-agent2-plugin-postgresql
