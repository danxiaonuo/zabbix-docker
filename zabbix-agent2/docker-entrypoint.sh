#!/bin/bash

set -o pipefail

set +e

# Script trace mode
if [ "${DEBUG_MODE,,}" == "true" ]; then
    set -o xtrace
fi

# Default Zabbix installation name
# Default Zabbix server host
: ${ZBX_SERVER_HOST:="0.0.0.0/0"}
# Default Zabbix server port number
: ${ZBX_SERVER_PORT:="16168"}

# Default directories
# Internal directory for TLS related files, used when TLS*File specified as plain text values
ZABBIX_INTERNAL_ENC_DIR="${ZABBIX_USER_HOME_DIR}/enc_internal"

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

    local masklist=("TLSPSKIdentity")

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
    elif [ "$(grep -Ec "^[#;] $var_name=" $config_path)" -gt 0 ]; then
        sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=$var_value/" "$config_path"
        echo "added"
    else
        sed -i -e '$a\' -e "$var_name=$var_value" "$config_path"
        echo "added at the end"
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

prepare_zbx_agent_config() {
    echo "** Preparing Zabbix agent configuration file"
    ZBX_AGENT_CONFIG=${ZABBIX_CONF_DIR}/zabbix_agent2.conf

    : ${ZBX_ACTIVESERVERS=""}

    update_config_var $ZBX_AGENT_CONFIG "PidFile"
    update_config_var $ZBX_AGENT_CONFIG "LogType" "console"
    update_config_var $ZBX_AGENT_CONFIG "LogFile"
    update_config_var $ZBX_AGENT_CONFIG "LogFileSize"
    update_config_var $ZBX_AGENT_CONFIG "DebugLevel" "${ZBX_DEBUGLEVEL}"
    update_config_var $ZBX_AGENT_CONFIG "SourceIP"
    update_config_var $ZBX_AGENT_CONFIG "Plugins.SystemRun.LogRemoteCommands" "${ZBX_LOGREMOTECOMMANDS}"
    update_config_var $ZBX_AGENT_CONFIG "Server" "${ZBX_SERVER_HOST}"
    update_config_var $ZBX_AGENT_CONFIG "ListenPort" "${ZBX_LISTENPORT}"
    update_config_var $ZBX_AGENT_CONFIG "ListenIP" "${ZBX_LISTENIP}"

    : ${ZBX_ACTIVE_ALLOW:="true"}
    if [ "${ZBX_ACTIVE_ALLOW,,}" == "true" ]; then
        echo "** Using '$ZBX_ACTIVESERVERS' servers for active checks"
        update_config_var $ZBX_AGENT_CONFIG "ServerActive" "${ZBX_ACTIVESERVERS}"
    else
        update_config_var $ZBX_AGENT_CONFIG "ServerActive"
    fi
    update_config_var $ZBX_AGENT_CONFIG "HeartbeatFrequency" "${ZBX_HEARTBEAT_FREQUENCY}"
    update_config_var $ZBX_AGENT_CONFIG "ForceActiveChecksOnStart" "${ZBX_FORCEACTIVECHECKSONSTART}"

    if [ "${ZBX_ENABLEPERSISTENTBUFFER,,}" == "true" ]; then
        update_config_var $ZBX_AGENT_CONFIG "EnablePersistentBuffer" "1"
        update_config_var $ZBX_AGENT_CONFIG "PersistentBufferFile" "$ZABBIX_USER_HOME_DIR/buffer/agent2.db"
        update_config_var $ZBX_AGENT_CONFIG "PersistentBufferPeriod" "${ZBX_PERSISTENTBUFFERPERIOD}"
    else
        update_config_var $ZBX_AGENT_CONFIG "EnablePersistentBuffer" "0"
    fi

    if [ "${ZBX_ENABLESTATUSPORT,,}" == "true" ]; then
        update_config_var $ZBX_AGENT_CONFIG "StatusPort" "31999"
    fi

    update_config_var $ZBX_AGENT_CONFIG "HostInterface" "${ZBX_HOSTINTERFACE}"
    update_config_var $ZBX_AGENT_CONFIG "HostInterfaceItem" "${ZBX_HOSTINTERFACEITEM}"

    update_config_var $ZBX_AGENT_CONFIG "Hostname" "${ZBX_HOSTNAME}"
    update_config_var $ZBX_AGENT_CONFIG "HostnameItem" "${ZBX_HOSTNAMEITEM}"
    update_config_var $ZBX_AGENT_CONFIG "HostMetadata" "${ZBX_METADATA}"
    update_config_var $ZBX_AGENT_CONFIG "HostMetadataItem" "${ZBX_METADATAITEM}"
    update_config_var $ZBX_AGENT_CONFIG "RefreshActiveChecks" "${ZBX_REFRESHACTIVECHECKS}"
    update_config_var $ZBX_AGENT_CONFIG "BufferSend" "${ZBX_BUFFERSEND}"
    update_config_var $ZBX_AGENT_CONFIG "BufferSize" "${ZBX_BUFFERSIZE}"
    update_config_var $ZBX_AGENT_CONFIG "Plugins.Log.MaxLinesPerSecond" "${ZBX_MAXLINESPERSECOND}"
    # Please use include to enable Alias feature
    # update_config_multiple_var $ZBX_AGENT_CONFIG "Alias" ${ZBX_ALIAS}
    update_config_var $ZBX_AGENT_CONFIG "Timeout" "${ZBX_TIMEOUT}"
    # update_config_var $ZBX_AGENT_CONFIG "Include" "${ZABBIX_ETC_DIR}/zabbix_agent2.d/plugins.d/*.conf"
    update_config_var $ZBX_AGENT_CONFIG "Include" "${ZABBIX_ETC_DIR}/zabbix_agentd.conf.d/*.conf"
    update_config_var $ZBX_AGENT_CONFIG "UnsafeUserParameters" "${ZBX_UNSAFEUSERPARAMETERS}"
    update_config_var $ZBX_AGENT_CONFIG "TLSConnect" "${ZBX_TLSCONNECT}"
    update_config_var $ZBX_AGENT_CONFIG "TLSAccept" "${ZBX_TLSACCEPT}"
    update_config_var $ZBX_AGENT_CONFIG "TLSCAFile" "${ZBX_TLSCAFILE}"
    update_config_var $ZBX_AGENT_CONFIG "TLSCRLFile" "${ZBX_TLSCRLFILE}"
    update_config_var $ZBX_AGENT_CONFIG "TLSServerCertIssuer" "${ZBX_TLSSERVERCERTISSUER}"
    update_config_var $ZBX_AGENT_CONFIG "TLSServerCertSubject" "${ZBX_TLSSERVERCERTSUBJECT}"
    update_config_var $ZBX_AGENT_CONFIG "TLSCertFile" "${ZBX_TLSCERTFILE}"
    update_config_var $ZBX_AGENT_CONFIG "TLSKeyFile" "${ZBX_TLSKEYFILE}"
    update_config_var $ZBX_AGENT_CONFIG "TLSPSKIdentity" "${ZBX_TLSPSKIDENTITY}"
    update_config_var $ZBX_AGENT_CONFIG "TLSPSKFile" "${ZBX_TLSPSKFILE}"

    update_config_multiple_var $ZBX_AGENT_CONFIG "DenyKey" "${ZBX_DENYKEY}"
    update_config_multiple_var $ZBX_AGENT_CONFIG "AllowKey" "${ZBX_ALLOWKEY}"
}

prepare_zbx_agent_plugin_config() {
    echo "** Preparing Zabbix agent plugin configuration files"

    sed -i "/AllowKey=.*/i\Include=${ZABBIX_ETC_DIR}/zabbix_agent2.d/plugins.d/*.conf" ${ZBX_AGENT_CONFIG}
    # update_config_var "${ZABBIX_ETC_DIR}/zabbix_agent2.d/plugins.d/mongodb.conf" "Plugins.MongoDB.System.Path" "/usr/sbin/zabbix-agent2-plugin/mongodb"
    # update_config_var "${ZABBIX_ETC_DIR}/zabbix_agent2.d/plugins.d/postgresql.conf" "Plugins.PostgreSQL.System.Path" "/usr/sbin/zabbix-agent2-plugin/postgresql"
    update_config_var "${ZABBIX_ETC_DIR}/zabbix_agent2.d/plugins.d/mssql.conf" "Plugins.MSSQL.System.Path" "/usr/sbin/zabbix-agent2-plugin/mssql"
    update_config_var "${ZABBIX_ETC_DIR}/zabbix_agent2.d/plugins.d/ember.conf" "Plugins.EmberPlus.System.Path" "/usr/sbin/zabbix-agent2-plugin/ember-plus"
}
clear_zbx_env() {
    [[ "${ZBX_CLEAR_ENV}" == "false" ]] && return

    for env_var in $(env | grep -E "^ZBX_"); do
        unset "${env_var%%=*}"
    done
}

prepare_permissions() {
   sudo chown -R zabbix:zabbix ${ZABBIX_USER_HOME_DIR} && sudo chmod -R 775 ${ZABBIX_USER_HOME_DIR}
}


prepare_agent() {
    echo "** Preparing Zabbix agent"
    prepare_zbx_agent_config
    prepare_zbx_agent_plugin_config
    clear_zbx_env
	  prepare_permissions
}

#################################################

if [ "${1#-}" != "$1" ]; then
    set -- /usr/sbin/zabbix_agent2 "$@"
fi

if [ "$1" == '/usr/sbin/zabbix_agent2' ]; then
    prepare_agent
fi

exec "$@"

#################################################
