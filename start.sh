#!/bin/bash

dirpath="$(cd "$(dirname "$0")" && pwd)"
cd $dirpath

JAVA_HOME=[#JAVA_HOME]
APP_MAIN=com.wetech.settlement.RouterApplication
APP_NAME="settlement-router"
CLASSPATH='conf/:app/router.jar:libs/*'
CURRENT_DIR=`pwd`
LOG_DIR=${CURRENT_DIR}/logs
CONF_DIR=${CURRENT_DIR}/conf
os_platform=`uname -s`


mkdir -p logs

# 初始化全局变量，用于标识系统的PID（0表示未启动）
tradePortalPID=0
start_timestamp=0

getTradeProtalPID(){
    tradePortalPID=0
    pids=$($JAVA_HOME/bin/jps -l | grep "$APP_MAIN" | awk '{print $1}')
    for pid in $pids; do
        case "$os_platform" in
            Linux)
                wd=$(readlink -f /proc/$pid/cwd 2>/dev/null)
                ;;
            Darwin)
                wd=$(lsof -p $pid 2>/dev/null | grep cwd | awk '{print $9}')
                ;;
            *)
                echo "Unsupported platform: $os_platform"
                exit 1
                ;;
        esac
        if [ "$wd" = "$CURRENT_DIR" ]; then
            tradePortalPID=$pid
            break
        fi
    done
}

JAVA_OPTS=" -Dfile.encoding=UTF-8 -Dcom.sun.management.jmxremote.ssl=false"

JAVA_OPTS+=" -Dlog4j.configurationfile=${CONF_DIR}/log4j2.xml -Dindex.log.home=${LOG_DIR} -Dconfig=${CONF_DIR}/"
JAVA_OPTS+=" -Xmx512m -Xms512m -XX:NewSize=256m -XX:MaxNewSize=256m"
JAVA_OPTS+=" -XX:CompileThreshold=20000"
JAVA_OPTS+=" -XX:+DisableExplicitGC -XX:+PrintGCDetails -Xloggc:${LOG_DIR}/jvm.log"
JAVA_OPTS+=" -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${LOG_DIR}/ -XX:ErrorFile=${LOG_DIR}/heap_error.log"
JAVA_OPTS+=" -Ddruid.mysql.usePingMethod=false"

function get_start_time() {
    start_time=$(date "+%Y-%m-%d %H:%M:%S")
    if [[ "${os_platform}" = "Darwin" ]];then
        start_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "${start_time}" +%s)
    elif [[ "${os_platform}" = "Linux" ]];then
        start_timestamp=$(date -d "${start_time}" +%s)
    else
        echo -e "\033[31m[ERROR] Server start fail!\033[0m"
        echo "check platform...[failed]"
        echo "3" > ${file_failed_path}
        echo "==============================================================================================="
        kill $tradePortalPID
        exit 1
    fi
}

function waiting_for_start() {
    i=0
    while [ $i -le 30 ]
    do
        for j in '\\' '|' '/' '-'
        do
            printf "%c%c%c%c%c Waiting for server started %c%c%c%c%c\r" \
            "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j"
            check_time=$(tail -n 100 ./logs/${APP_NAME}.log | grep -aE "process running for" | tail -n 1 | awk -F "]" '{print $3}' | awk -F "[" '{print $2}' | awk -F " " '{print $1, $2}')
            if [ -n "$check_time" ]; then
                if [[ "${os_platform}" = "Darwin" ]];then
                    timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "${check_time}" +%s)
                elif [[ "${os_platform}" = "Linux" ]];then
                    timestamp=$(date -d "${check_time}" +%s)
                else
                    echo -e "\033[31m[ERROR] Server start fail!\033[0m"
                    echo "check platform...[failed]"
                    echo "1" > ${file_failed_path}
                    echo "==============================================================================================="
                    kill $tradePortalPID
                    exit 1
                fi
                if [[ ${timestamp} -gt ${start_timestamp} ]]; then
                    echo ""
                    echo -e "\033[32m[INFO] Server start Successful!\033[0m"
                    echo "(PID=$tradePortalPID)...[Success]"
                    echo "0" > ${file_success_path}
                    echo "==============================================================================================="
                    exit 0
                fi
            fi
            sleep 1
        done
        let i=i+5
    done
    echo ""
    echo -e "\033[31m[ERROR] Server start fail!\033[0m"
    echo "timeout...[failed]"
    echo "2" > ${file_failed_path}
    echo "==============================================================================================="
    kill $tradePortalPID
    exit 1
}

start(){
    echo ""
    file_success_path="./success"
    if [ -e "$file_success_path" ]; then
        rm "$file_success_path"
    fi
    file_failed_path="./failed"
    if [ -e "$file_failed_path" ]; then
        rm "$file_failed_path"
    fi
    getTradeProtalPID
    echo "==============================================================================================="
    if [ $tradePortalPID -ne 0 ]; then
        echo "$APP_MAIN already started(PID=$tradePortalPID)"
        echo "==============================================================================================="
    else
        get_start_time
        echo "Starting $APP_MAIN... ${start_time} (${start_timestamp})"
        nohup $JAVA_HOME/bin/java $JAVA_OPTS -cp "$CLASSPATH" $APP_MAIN >start.out 2>&1 &
        sleep 1
        getTradeProtalPID
        if [ $tradePortalPID -ne 0 ]; then
            waiting_for_start
        else
            echo -e "\033[31m[ERROR] Server start fail!\033[0m"
            echo "[Failed]"
            echo "9" > ${file_failed_path}
            echo "==============================================================================================="
        fi
    fi
}

start
