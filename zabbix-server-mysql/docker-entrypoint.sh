#!/bin/bash

set -o pipefail

set +e

# Script trace mode
if [ "${DEBUG_MODE,,}" == "true" ]; then
    set -o xtrace
fi

# Default directories
# Internal directory for TLS related files, used when TLS*File specified as plain text values
ZABBIX_INTERNAL_ENC_DIR="${ZABBIX_USER_HOME_DIR}/enc_internal"

: ${DB_CHARACTER_SET:="utf8mb4"}
: ${DB_CHARACTER_COLLATE:="utf8mb4_bin"}

# usage: file_env VAR [DEFAULT]
# as example: file_env 'MYSQL_PASSWORD' 'zabbix'
#    (will allow for "$MYSQL_PASSWORD_FILE" to fill in the value of "$MYSQL_PASSWORD" from a file)
# unsets the VAR_FILE afterwards and just leaving VAR
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local defaultValue="${2:-}"

    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo "**** Both variables $var and $fileVar are set (but are exclusive)"
        exit 1
    fi

    local val="$defaultValue"

    if [ "${!var:-}" ]; then
        val="${!var}"
        echo "** Using ${var} variable from ENV"
    elif [ "${!fileVar:-}" ]; then
        if [ ! -f "${!fileVar}" ]; then
            echo "**** Secret file \"${!fileVar}\" is not found"
            exit 1
        fi
        val="$(< "${!fileVar}")"
        echo "** Using ${var} variable from secret file"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

escape_spec_char() {
    local var_value=$1

    var_value="${var_value//\\/\\\\}"
    var_value="${var_value//[$'\n']/}"
    var_value="${var_value//\//\\/}"
    var_value="${var_value//./\\.}"
    var_value="${var_value//\*/\\*}"
    var_value="${var_value//^/\\^}"
    var_value="${var_value//\$/\\\$}"
    var_value="${var_value//\&/\\\&}"
    var_value="${var_value//\[/\\[}"
    var_value="${var_value//\]/\\]}"

    echo "$var_value"
}

update_config_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3
    local is_multiple=$4

    local masklist=("DBPassword TLSPSKIdentity")

    if [ ! -f "$config_path" ]; then
        echo "**** Configuration file '$config_path' does not exist"
        return
    fi

    if [[ " ${masklist[@]} " =~ " $var_name " ]] && [ ! -z "$var_value" ]; then
        echo -n "** Updating '$config_path' parameter \"$var_name\": '****'. Enable DEBUG_MODE to view value ..."
    else
        echo -n "** Updating '$config_path' parameter \"$var_name\": '$var_value'..."
    fi

    # Remove configuration parameter definition in case of unset or empty parameter value
    if [ -z "$var_value" ]; then
        sed -i -e "/^$var_name=/d" "$config_path"
        echo "removed"
        return
    fi

    # Remove value from configuration parameter in case of set to double quoted parameter value
    if [[ "$var_value" == '""' ]]; then
        if [ "$(grep -E "^$var_name=" $config_path)" ]; then
            sed -i -e "/^$var_name=/s/=.*/=/" "$config_path"
        else
            sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=/" "$config_path"
        fi
        echo "undefined"
        return
    fi

    # Use full path to a file for TLS related configuration parameters
    if [[ $var_name =~ ^TLS.*File$ ]] && [[ ! $var_value =~ ^/.+$ ]]; then
        var_value=$ZABBIX_USER_HOME_DIR/enc/$var_value
    fi

    # Escaping characters in parameter value and name
    var_value=$(escape_spec_char "$var_value")
    var_name=$(escape_spec_char "$var_name")

    if [ "$(grep -E "^$var_name=$var_value$" $config_path)" ]; then
        echo "exists"
    elif [ "$(grep -E "^$var_name=" $config_path)" ] && [ "$is_multiple" != "true" ]; then
        sed -i -e "/^$var_name=/s/=.*/=$var_value/" "$config_path"
        echo "updated"
    elif [ "$(grep -Ec "^# $var_name=" $config_path)" -gt 1 ]; then
        sed -i -e  "/^[#;] $var_name=$/i\\$var_name=$var_value" "$config_path"
        echo "added first occurrence"
    else
        sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=$var_value/" "$config_path"
        echo "added"
    fi

}

update_config_multiple_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3

    var_value="${var_value%\"}"
    var_value="${var_value#\"}"

    local IFS=,
    local OPT_LIST=($var_value)

    for value in "${OPT_LIST[@]}"; do
        update_config_var $config_path $var_name $value true
    done
}

file_process_from_env() {
    local config_path=$1
    local var_name=$2
    local file_name=$3
    local var_value=$4

    if [ ! -z "$var_value" ]; then
        echo -n "$var_value" > "${ZABBIX_INTERNAL_ENC_DIR}/$var_name"
        file_name="${ZABBIX_INTERNAL_ENC_DIR}/${var_name}"
    fi
    update_config_var $config_path "$var_name" "$file_name"
}

# Check prerequisites for MySQL database
check_variables_mysql() {
    if [ ! -n "${DB_SERVER_SOCKET}" ]; then
        : ${DB_SERVER_HOST:="mysql-server"}
        : ${DB_SERVER_PORT:="3306"}
    fi

    USE_DB_ROOT_USER=false
    CREATE_ZBX_DB_USER=false
    file_env MYSQL_USER
    file_env MYSQL_PASSWORD

    file_env MYSQL_ROOT_USER
    file_env MYSQL_ROOT_PASSWORD

    if [ ! -n "${MYSQL_USER}" ] && [ "${MYSQL_RANDOM_ROOT_PASSWORD,,}" == "true" ]; then
        echo "**** Impossible to use MySQL server because of unknown Zabbix user and random 'root' password"
        exit 1
    fi

    if [ ! -n "${MYSQL_USER}" ] && [ ! -n "${MYSQL_ROOT_PASSWORD}" ] && [ "${MYSQL_ALLOW_EMPTY_PASSWORD,,}" != "true" ]; then
        echo "*** Impossible to use MySQL server because 'root' password is not defined and it is not empty"
        exit 1
    fi

    if [ "${MYSQL_ALLOW_EMPTY_PASSWORD,,}" == "true" ] || [ -n "${MYSQL_ROOT_PASSWORD}" ]; then
        USE_DB_ROOT_USER=true
        DB_SERVER_ROOT_USER=${MYSQL_ROOT_USER:-"root"}
        DB_SERVER_ROOT_PASS=${MYSQL_ROOT_PASSWORD:-""}
    fi

    [ -n "${MYSQL_USER}" ] && [ "${USE_DB_ROOT_USER}" == "true" ] && CREATE_ZBX_DB_USER=true

    # If root password is not specified use provided credentials
    : ${DB_SERVER_ROOT_USER:=${MYSQL_USER}}
    [ "${MYSQL_ALLOW_EMPTY_PASSWORD,,}" == "true" ] || DB_SERVER_ROOT_PASS=${DB_SERVER_ROOT_PASS:-${MYSQL_PASSWORD}}
    DB_SERVER_ZBX_USER=${MYSQL_USER:-"zabbix"}
    DB_SERVER_ZBX_PASS=${MYSQL_PASSWORD:-"zabbix"}

    DB_SERVER_DBNAME=${MYSQL_DATABASE:-"zabbix"}

    if [ ! -n "${DB_SERVER_SOCKET}" ]; then
        mysql_connect_args="-h ${DB_SERVER_HOST} -P ${DB_SERVER_PORT}"
    else
        mysql_connect_args="-S ${DB_SERVER_SOCKET}"
    fi
}

db_tls_params() {
    local result=""

    if [ -n "${ZBX_DBTLSCONNECT}" ]; then
        ssl_mode=${ZBX_DBTLSCONNECT//verify_full/verify_identity}
        result="--ssl-mode=$ssl_mode"

        if [ -n "${ZBX_DBTLSCAFILE}" ]; then
            result="${result} --ssl-ca=${ZBX_DBTLSCAFILE}"
        fi

        if [ -n "${ZBX_DBTLSKEYFILE}" ]; then
            result="${result} --ssl-key=${ZBX_DBTLSKEYFILE}"
        fi

        if [ -n "${ZBX_DBTLSCERTFILE}" ]; then
            result="${result} --ssl-cert=${ZBX_DBTLSCERTFILE}"
        fi
    fi

    echo $result
}

check_db_connect_mysql() {
    echo "********************"
    if [ ! -n "${DB_SERVER_SOCKET}" ]; then
        echo "* DB_SERVER_HOST: ${DB_SERVER_HOST}"
        echo "* DB_SERVER_PORT: ${DB_SERVER_PORT}"
    else
        echo "* DB_SERVER_SOCKET: ${DB_SERVER_SOCKET}"
    fi
    echo "* DB_SERVER_DBNAME: ${DB_SERVER_DBNAME}"
    if [ "${DEBUG_MODE,,}" == "true" ]; then
        if [ "${USE_DB_ROOT_USER}" == "true" ]; then
            echo "* DB_SERVER_ROOT_USER: ${DB_SERVER_ROOT_USER}"
            echo "* DB_SERVER_ROOT_PASS: ${DB_SERVER_ROOT_PASS}"
        fi
        echo "* DB_SERVER_ZBX_USER: ${DB_SERVER_ZBX_USER}"
        echo "* DB_SERVER_ZBX_PASS: ${DB_SERVER_ZBX_PASS}"
    fi
    echo "********************"

    WAIT_TIMEOUT=5

    ssl_opts="$(db_tls_params)"

    export MYSQL_PWD="${DB_SERVER_ROOT_PASS}"

    while [ ! "$(mysqladmin ping $mysql_connect_args -u ${DB_SERVER_ROOT_USER} \
                --silent --connect_timeout=10 $ssl_opts)" ]; do
        echo "**** MySQL server is not available. Waiting $WAIT_TIMEOUT seconds..."
        sleep $WAIT_TIMEOUT
    done

    unset MYSQL_PWD
}

mysql_query() {
    query=$1
    local result=""

    ssl_opts="$(db_tls_params)"

    export MYSQL_PWD="${DB_SERVER_ROOT_PASS}"

    result=$(mysql --silent --skip-column-names $mysql_connect_args \
             -u ${DB_SERVER_ROOT_USER} -e "$query" $ssl_opts)

    unset MYSQL_PWD

    echo $result
}

exec_sql_file() {
    sql_script=$1

    local command="cat"

    ssl_opts="$(db_tls_params)"

    export MYSQL_PWD="${DB_SERVER_ROOT_PASS}"

    if [ "${sql_script: -3}" == ".gz" ]; then
        command="zcat"
    fi

    $command "$sql_script" | mysql --silent --skip-column-names \
            --default-character-set=${DB_CHARACTER_SET} \
            $mysql_connect_args \
            -u ${DB_SERVER_ROOT_USER} $ssl_opts  \
            ${DB_SERVER_DBNAME} 1>/dev/null

    unset MYSQL_PWD
}

create_db_user_mysql() {
    [ "${CREATE_ZBX_DB_USER}" == "true" ] || return

    echo "** Creating '${DB_SERVER_ZBX_USER}' user in MySQL database"

    USER_EXISTS=$(mysql_query "SELECT 1 FROM mysql.user WHERE user = '${DB_SERVER_ZBX_USER}' AND host = '%'")

    if [ -z "$USER_EXISTS" ]; then
        mysql_query "CREATE USER '${DB_SERVER_ZBX_USER}'@'%' IDENTIFIED BY '${DB_SERVER_ZBX_PASS}'" 1>/dev/null
    else
        mysql_query "ALTER USER ${DB_SERVER_ZBX_USER} IDENTIFIED BY '${DB_SERVER_ZBX_PASS}';" 1>/dev/null
    fi

    mysql_query "GRANT ALL PRIVILEGES ON $DB_SERVER_DBNAME. * TO '${DB_SERVER_ZBX_USER}'@'%'" 1>/dev/null
}

create_db_database_mysql() {
    DB_EXISTS=$(mysql_query "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_SERVER_DBNAME}'")

    if [ -z ${DB_EXISTS} ]; then
        echo "** Database '${DB_SERVER_DBNAME}' does not exist. Creating..."
        mysql_query "CREATE DATABASE ${DB_SERVER_DBNAME} CHARACTER SET ${DB_CHARACTER_SET} COLLATE ${DB_CHARACTER_COLLATE}" 1>/dev/null
        # better solution?
        mysql_query "GRANT ALL PRIVILEGES ON $DB_SERVER_DBNAME. * TO '${DB_SERVER_ZBX_USER}'@'%'" 1>/dev/null
    else
        echo "** Database '${DB_SERVER_DBNAME}' already exists. Please be careful with database COLLATE!"
    fi
}

apply_db_scripts() {
    db_scripts=$1

    for sql_script in $db_scripts; do
        [ -e "$sql_script" ] || continue
        echo "** Processing additional '$sql_script' SQL script"

        exec_sql_file "$sql_script"
    done
}

create_db_schema_mysql() {
    DBVERSION_TABLE_EXISTS=$(mysql_query "SELECT 1 FROM information_schema.tables WHERE table_schema='${DB_SERVER_DBNAME}' and table_name = 'dbversion'")

    if [ -n "${DBVERSION_TABLE_EXISTS}" ]; then
        echo "** Table '${DB_SERVER_DBNAME}.dbversion' already exists."
        ZBX_DB_VERSION=$(mysql_query "SELECT mandatory FROM ${DB_SERVER_DBNAME}.dbversion")
    fi

    if [ -z "${ZBX_DB_VERSION}" ]; then
        echo "** Creating '${DB_SERVER_DBNAME}' schema in MySQL"

        exec_sql_file "${ZABBIX_USER_HOME_DIR}/share/doc/zabbix-server-mysql/create.sql.gz"

        apply_db_scripts "${ZABBIX_USER_HOME_DIR}/dbscripts/*.sql"
    fi
}

update_zbx_config() {
    echo "** Preparing Zabbix server configuration file"

    ZBX_CONFIG=$ZABBIX_CONF_DIR/zabbix_server.conf

    update_config_var $ZBX_CONFIG "ListenIP" "${ZBX_LISTENIP}"
    update_config_var $ZBX_CONFIG "ListenPort" "${ZBX_LISTENPORT}"
    update_config_var $ZBX_CONFIG "ListenBacklog" "${ZBX_LISTENBACKLOG}"

    update_config_var $ZBX_CONFIG "SourceIP" "${ZBX_SOURCEIP}"
    update_config_var $ZBX_CONFIG "LogType" "console"
    update_config_var $ZBX_CONFIG "LogFile"
    update_config_var $ZBX_CONFIG "LogFileSize"
    update_config_var $ZBX_CONFIG "PidFile"

    update_config_var $ZBX_CONFIG "DebugLevel" "${ZBX_DEBUGLEVEL}"

    if [ -n "${ZBX_DBTLSCONNECT}" ]; then
        update_config_var $ZBX_CONFIG "DBTLSConnect" "${ZBX_DBTLSCONNECT}"
        update_config_var $ZBX_CONFIG "DBTLSCAFile" "${ZBX_DBTLSCAFILE}"
        update_config_var $ZBX_CONFIG "DBTLSCertFile" "${ZBX_DBTLSCERTFILE}"
        update_config_var $ZBX_CONFIG "DBTLSKeyFile" "${ZBX_DBTLSKEYFILE}"
        update_config_var $ZBX_CONFIG "DBTLSCipher" "${ZBX_DBTLSCIPHER}"
        update_config_var $ZBX_CONFIG "DBTLSCipher13" "${ZBX_DBTLSCIPHER13}"
    fi

    if [ ! -n "${DB_SERVER_SOCKET}" ]; then
        update_config_var $ZBX_CONFIG "DBHost" "${DB_SERVER_HOST}"
        update_config_var $ZBX_CONFIG "DBPort" "${DB_SERVER_PORT}"
    else
        update_config_var $ZBX_CONFIG "DBHost"
        update_config_var $ZBX_CONFIG "DBPort"
    fi
    update_config_var $ZBX_CONFIG "DBSocket" "${DB_SERVER_SOCKET}"
    update_config_var $ZBX_CONFIG "DBName" "${DB_SERVER_DBNAME}"
    update_config_var $ZBX_CONFIG "DBSchema" "${DB_SERVER_SCHEMA}"

    if [ -n "${ZBX_VAULT}" ] && [ -n "${ZBX_VAULTURL}" ]; then
        update_config_var $ZBX_CONFIG "Vault" "${ZBX_VAULT}"
        update_config_var $ZBX_CONFIG "VaultTLSCertFile" "${ZBX_VAULTTLSCERTFILE}"
        update_config_var $ZBX_CONFIG "VaultTLSKeyFile" "${ZBX_VAULTTLSKEYFILE}"
        update_config_var $ZBX_CONFIG "VaultPrefix" "${ZBX_VAULTPREFIX}"
        update_config_var $ZBX_CONFIG "VaultURL" "${ZBX_VAULTURL}"
        update_config_var $ZBX_CONFIG "VaultDBPath" "${ZBX_VAULTDBPATH}"

        if [ -n "${ZBX_VAULTDBPATH}" ]; then
            update_config_var $ZBX_CONFIG "DBUser"
            update_config_var $ZBX_CONFIG "DBPassword"
        else
            update_config_var $ZBX_CONFIG "DBUser" "${DB_SERVER_ZBX_USER}"
            update_config_var $ZBX_CONFIG "DBPassword" "${DB_SERVER_ZBX_PASS}"
        fi
    else
        update_config_var $ZBX_CONFIG "Vault"
        update_config_var $ZBX_CONFIG "VaultTLSCertFile"
        update_config_var $ZBX_CONFIG "VaultTLSKeyFile"
        update_config_var $ZBX_CONFIG "VaultPrefix"
        update_config_var $ZBX_CONFIG "VaultURL"
        update_config_var $ZBX_CONFIG "VaultDBPath"

        update_config_var $ZBX_CONFIG "DBUser" "${DB_SERVER_ZBX_USER}"
        update_config_var $ZBX_CONFIG "DBPassword" "${DB_SERVER_ZBX_PASS}"
    fi

    update_config_var $ZBX_CONFIG "AllowUnsupportedDBVersions" "${ZBX_ALLOWUNSUPPORTEDDBVERSIONS}"
    update_config_var $ZBX_CONFIG "MaxConcurrentChecksPerPoller" "${ZBX_MAXCONCURRENTCHECKSPERPOLLER}"
    update_config_var $ZBX_CONFIG "EnableGlobalScripts" "${ZBX_ENABLEGLOBALSCRIPTS}"

    update_config_var $ZBX_CONFIG "StartReportWriters" "${ZBX_STARTREPORTWRITERS}"
    : ${ZBX_WEBSERVICEURL:="http://zabbix-web-service:10053/report"}
    update_config_var $ZBX_CONFIG "WebServiceURL" "${ZBX_WEBSERVICEURL}"

    update_config_var $ZBX_CONFIG "HistoryStorageURL" "${ZBX_HISTORYSTORAGEURL}"
    update_config_var $ZBX_CONFIG "HistoryStorageTypes" "${ZBX_HISTORYSTORAGETYPES}"
    update_config_var $ZBX_CONFIG "HistoryStorageDateIndex" "${ZBX_HISTORYSTORAGEDATEINDEX}"

    update_config_var $ZBX_CONFIG "StatsAllowedIP" "${ZBX_STATSALLOWEDIP}"

    update_config_var $ZBX_CONFIG "StartPollers" "${ZBX_STARTPOLLERS}"
    update_config_var $ZBX_CONFIG "StartIPMIPollers" "${ZBX_STARTIPMIPOLLERS}"
    update_config_var $ZBX_CONFIG "StartPollersUnreachable" "${ZBX_STARTPOLLERSUNREACHABLE}"
    update_config_var $ZBX_CONFIG "StartTrappers" "${ZBX_STARTTRAPPERS}"
    update_config_var $ZBX_CONFIG "StartPingers" "${ZBX_STARTPINGERS}"
    update_config_var $ZBX_CONFIG "StartDiscoverers" "${ZBX_STARTDISCOVERERS}"
    update_config_var $ZBX_CONFIG "StartHistoryPollers" "${ZBX_STARTHISTORYPOLLERS}"
    update_config_var $ZBX_CONFIG "StartHTTPAgentPollers" "${ZBX_STARTHTTPAGENTPOLLERS}"
    update_config_var $ZBX_CONFIG "StartHTTPPollers" "${ZBX_STARTHTTPPOLLERS}"
    update_config_var $ZBX_CONFIG "StartODBCPollers" "${ZBX_STARTODBCPOLLERS}"
    update_config_var $ZBX_CONFIG "StartSNMPPollers" "${ZBX_STARTSNMPPOLLERS}"

    update_config_var $ZBX_CONFIG "StartConnectors" "${ZBX_STARTCONNECTORS}"
    update_config_var $ZBX_CONFIG "StartPreprocessors" "${ZBX_STARTPREPROCESSORS}"
    update_config_var $ZBX_CONFIG "StartTimers" "${ZBX_STARTTIMERS}"
    update_config_var $ZBX_CONFIG "StartEscalators" "${ZBX_STARTESCALATORS}"
    update_config_var $ZBX_CONFIG "StartAgentPollers" "${ZBX_STARTAGENTPOLLERS}"
    update_config_var $ZBX_CONFIG "StartAlerters" "${ZBX_STARTALERTERS}"
    update_config_var $ZBX_CONFIG "StartTimers" "${ZBX_STARTTIMERS}"
    update_config_var $ZBX_CONFIG "StartEscalators" "${ZBX_STARTESCALATORS}"

    update_config_var $ZBX_CONFIG "StartLLDProcessors" "${ZBX_STARTLLDPROCESSORS}"

    : ${ZBX_JAVAGATEWAY_ENABLE:="false"}
    if [ "${ZBX_JAVAGATEWAY_ENABLE,,}" == "true" ]; then
        update_config_var $ZBX_CONFIG "JavaGateway" "${ZBX_JAVAGATEWAY:-"zabbix-java-gateway"}"
        update_config_var $ZBX_CONFIG "JavaGatewayPort" "${ZBX_JAVAGATEWAYPORT}"
        update_config_var $ZBX_CONFIG "StartJavaPollers" "${ZBX_STARTJAVAPOLLERS:-"5"}"
    else
        update_config_var $ZBX_CONFIG "JavaGateway"
        update_config_var $ZBX_CONFIG "JavaGatewayPort"
        update_config_var $ZBX_CONFIG "StartJavaPollers"
    fi

    update_config_var $ZBX_CONFIG "StartVMwareCollectors" "${ZBX_STARTVMWARECOLLECTORS}"
    update_config_var $ZBX_CONFIG "VMwareFrequency" "${ZBX_VMWAREFREQUENCY}"
    update_config_var $ZBX_CONFIG "VMwarePerfFrequency" "${ZBX_VMWAREPERFFREQUENCY}"
    update_config_var $ZBX_CONFIG "VMwareCacheSize" "${ZBX_VMWARECACHESIZE}"
    update_config_var $ZBX_CONFIG "VMwareTimeout" "${ZBX_VMWARETIMEOUT}"

    : ${ZBX_ENABLE_SNMP_TRAPS:="false"}
    if [ "${ZBX_ENABLE_SNMP_TRAPS,,}" == "true" ]; then
        update_config_var $ZBX_CONFIG "SNMPTrapperFile" "${ZABBIX_USER_HOME_DIR}/snmptraps/snmptraps.log"
        update_config_var $ZBX_CONFIG "StartSNMPTrapper" "1"
    else
        update_config_var $ZBX_CONFIG "SNMPTrapperFile"
        update_config_var $ZBX_CONFIG "StartSNMPTrapper"
    fi

    update_config_var $ZBX_CONFIG "SocketDir" "/tmp/"

    update_config_var $ZBX_CONFIG "HousekeepingFrequency" "${ZBX_HOUSEKEEPINGFREQUENCY}"
    update_config_var $ZBX_CONFIG "MaxHousekeeperDelete" "${ZBX_MAXHOUSEKEEPERDELETE}"
    update_config_var $ZBX_CONFIG "ProblemHousekeepingFrequency" "${ZBX_PROBLEMHOUSEKEEPINGFREQUENCY}"

    update_config_var $ZBX_CONFIG "CacheSize" "${ZBX_CACHESIZE}"

    update_config_var $ZBX_CONFIG "CacheUpdateFrequency" "${ZBX_CACHEUPDATEFREQUENCY}"

    update_config_var $ZBX_CONFIG "StartDBSyncers" "${ZBX_STARTDBSYNCERS}"
    update_config_var $ZBX_CONFIG "HistoryCacheSize" "${ZBX_HISTORYCACHESIZE}"
    update_config_var $ZBX_CONFIG "HistoryIndexCacheSize" "${ZBX_HISTORYINDEXCACHESIZE}"

    update_config_var $ZBX_CONFIG "TrendCacheSize" "${ZBX_TRENDCACHESIZE}"
    update_config_var $ZBX_CONFIG "TrendFunctionCacheSize" "${ZBX_TRENDFUNCTIONCACHESIZE}"
    update_config_var $ZBX_CONFIG "ValueCacheSize" "${ZBX_VALUECACHESIZE}"

    update_config_var $ZBX_CONFIG "Timeout" "${ZBX_TIMEOUT}"
    update_config_var $ZBX_CONFIG "TrapperTimeout" "${ZBX_TRAPPERTIMEOUT}"
    update_config_var $ZBX_CONFIG "UnreachablePeriod" "${ZBX_UNREACHABLEPERIOD}"
    update_config_var $ZBX_CONFIG "UnavailableDelay" "${ZBX_UNAVAILABLEDELAY}"
    update_config_var $ZBX_CONFIG "UnreachableDelay" "${ZBX_UNREACHABLEDELAY}"

    update_config_var $ZBX_CONFIG "AlertScriptsPath" "${ZABBIX_USER_HOME_DIR}/alertscripts"
    update_config_var $ZBX_CONFIG "ExternalScripts" "${ZABBIX_USER_HOME_DIR}/externalscripts"
    update_config_var $ZBX_CONFIG "Include" "${ZABBIX_CONF_DIR}/zabbix_proxy.conf.d/*.conf"

    if [ -n "${ZBX_EXPORTFILESIZE}" ]; then
        update_config_var $ZBX_CONFIG "ExportDir" "$ZABBIX_USER_HOME_DIR/export/"
        update_config_var $ZBX_CONFIG "ExportFileSize" "${ZBX_EXPORTFILESIZE}"
        update_config_var $ZBX_CONFIG "ExportType" "${ZBX_EXPORTTYPE}"
    fi

    update_config_var $ZBX_CONFIG "FpingLocation" "/usr/bin/fping"
    update_config_var $ZBX_CONFIG "Fping6Location" "/usr/bin/fping6"

    update_config_var $ZBX_CONFIG "SSHKeyLocation" "$ZABBIX_USER_HOME_DIR/ssh_keys"
    update_config_var $ZBX_CONFIG "LogSlowQueries" "${ZBX_LOGSLOWQUERIES}"

    update_config_var $ZBX_CONFIG "StartProxyPollers" "${ZBX_STARTPROXYPOLLERS}"
    update_config_var $ZBX_CONFIG "ProxyConfigFrequency" "${ZBX_PROXYCONFIGFREQUENCY}"
    update_config_var $ZBX_CONFIG "ProxyDataFrequency" "${ZBX_PROXYDATAFREQUENCY}"

    update_config_var $ZBX_CONFIG "SSLCertLocation" "$ZABBIX_USER_HOME_DIR/ssl/certs/"
    update_config_var $ZBX_CONFIG "SSLKeyLocation" "$ZABBIX_USER_HOME_DIR/ssl/keys/"
    update_config_var $ZBX_CONFIG "SSLCALocation" "$ZABBIX_USER_HOME_DIR/ssl/ssl_ca/"
    update_config_var $ZBX_CONFIG "LoadModulePath" "$ZABBIX_USER_HOME_DIR/modules/"
    update_config_multiple_var $ZBX_CONFIG "LoadModule" "${ZBX_LOADMODULE}"

    file_process_from_env $ZBX_CONFIG "TLSCAFile" "${ZBX_TLSCAFILE}" "${ZBX_TLSCA}"
    file_process_from_env $ZBX_CONFIG "TLSCRLFile" "${ZBX_TLSCRLFILE}" "${ZBX_TLSCRL}"

    file_process_from_env $ZBX_CONFIG "TLSCertFile" "${ZBX_TLSCERTFILE}" "${ZBX_TLSCERT}"
    update_config_var $ZBX_CONFIG "TLSCipherAll" "${ZBX_TLSCIPHERALL}"
    update_config_var $ZBX_CONFIG "TLSCipherAll13" "${ZBX_TLSCIPHERALL13}"
    update_config_var $ZBX_CONFIG "TLSCipherCert" "${ZBX_TLSCIPHERCERT}"
    update_config_var $ZBX_CONFIG "TLSCipherCert13" "${ZBX_TLSCIPHERCERT13}"
    update_config_var $ZBX_CONFIG "TLSCipherPSK" "${ZBX_TLSCIPHERPSK}"
    update_config_var $ZBX_CONFIG "TLSCipherPSK13" "${ZBX_TLSCIPHERPSK13}"
    file_process_from_env $ZBX_CONFIG "TLSKeyFile" "${ZBX_TLSKEYFILE}" "${ZBX_TLSKEY}"

    update_config_var $ZBX_CONFIG "ServiceManagerSyncFrequency" "${ZBX_SERVICEMANAGERSYNCFREQUENCY}"
    update_config_var $ZBX_CONFIG "AllowSoftwareUpdateCheck" "${ZBX_ALLOWSOFTWAREUPDATECHECK}"

    update_config_var $ZBX_CONFIG "SMSDevices" "${ZBX_SMSDEVICES}"

    if [ "${ZBX_AUTOHANODENAME}" == 'fqdn' ] && [ ! -n "${ZBX_HANODENAME}" ]; then
        update_config_var $ZBX_CONFIG "HANodeName" "$(hostname -f)"
    elif [ "${ZBX_AUTOHANODENAME}" == 'hostname' ] && [ ! -n "${ZBX_HANODENAME}" ]; then
        update_config_var $ZBX_CONFIG "HANodeName" "$(hostname)"
    else
        update_config_var $ZBX_CONFIG "HANodeName" "${ZBX_HANODENAME}"
    fi

    : ${ZBX_NODEADDRESSPORT:="16168"}
    if [ "${ZBX_AUTONODEADDRESS}" == 'fqdn' ] && [ ! -n "${ZBX_NODEADDRESS}" ]; then
        update_config_var $ZBX_CONFIG "NodeAddress" "$(hostname -f):${ZBX_NODEADDRESSPORT}"
    elif [ "${ZBX_AUTONODEADDRESS}" == 'hostname' ] && [ ! -n "${ZBX_NODEADDRESS}" ]; then
        update_config_var $ZBX_CONFIG "NodeAddress" "$(hostname):${ZBX_NODEADDRESSPORT}"
    else
        update_config_var $ZBX_CONFIG "NodeAddress" "${ZBX_NODEADDRESS}"
    fi

    if [ "$(id -u)" != '0' ]; then
        update_config_var $ZBX_CONFIG "User" "$(whoami)"
    else
        update_config_var $ZBX_CONFIG "AllowRoot" "1"
    fi

    update_config_var $ZBX_CONFIG "WebDriverURL" "${ZBX_WEBDRIVERURL}"
    update_config_var $ZBX_CONFIG "StartBrowserPollers" "${ZBX_STARTBROWSERPOLLERS}"

    command -v openssl >/dev/null 2>&1 && openssl rehash -v "$ZABBIX_USER_HOME_DIR/ssl/ssl_ca/" 1>/dev/null
}

clear_zbx_env() {
    [[ "${ZBX_CLEAR_ENV}" == "false" ]] && return

    for env_var in $(env | grep -E "^(ZBX|DB|MYSQL)_"); do
        unset "${env_var%%=*}"
    done
}

prepare_db() {
    echo "** Preparing database"

    check_variables_mysql
    check_db_connect_mysql
    create_db_user_mysql
    create_db_database_mysql
    create_db_schema_mysql
}

prepare_permissions() {
   sudo chown -R zabbix:zabbix ${ZABBIX_USER_HOME_DIR} && sudo chmod -R 775 ${ZABBIX_USER_HOME_DIR}
}

prepare_server() {
    echo "** Preparing Zabbix server"

    prepare_db
    update_zbx_config
    clear_zbx_env
    prepare_permissions
}

#################################################

if [ "${1#-}" != "$1" ]; then
    set -- /usr/sbin/zabbix_server "$@"
fi

if [ "$1" == '/usr/sbin/zabbix_server' ]; then
    prepare_server
fi

if [ "$1" == "init_db_only" ]; then
    prepare_db
else
    exec "$@"
fi

#################################################
