#!/bin/bash

rm -rf start.out

dirpath="$(cd "$(dirname "$0")" && pwd)"
cd $dirpath

APP_MAIN=com.wetech.settlement.RouterApplication
CURRENT_DIR=`pwd`
CONF_DIR=${CURRENT_DIR}/conf
os_platform=`uname -s`

# 初始化全局变量，用于标识系统的PID（0表示未启动）
tradePortalPID=0

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

function waiting_for_stop() {
    i=0
    # 最多等待两分钟
    while [ $i -le 150 ]
    do
        for j in '\\' '|' '/' '-'
        do
            printf "%c%c%c%c%c Waiting for server to stop %c%c%c%c%c\r" \
            "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j" "$j"
            getTradeProtalPID
            if [ $tradePortalPID -eq 0 ]; then
                  echo -n ""
                  echo -e "\033[32m[INFO] Server Stop Successful!         \033[0m"
                  echo "==============================================================================================="
                  exit 0
            fi
            sleep 1
        done
        let i=i+5
    done
    echo ""
    echo -e "\033[31m[ERROR] Server stop fail!\033[0m"
    echo "timeout...[failed]"
    echo "==============================================================================================="
    exit 1
}

stop(){
    getTradeProtalPID
    echo "==============================================================================================="
    if [ $tradePortalPID -ne 0 ]; then
        echo -n "Stopping $APP_MAIN(PID=$tradePortalPID)..."
        echo ""
        kill $tradePortalPID > /dev/null
        echo "==============================================================================================="
        # sleep 5 # 等待5秒
        waiting_for_stop
    else
        echo "$APP_MAIN is not running"
        echo "==============================================================================================="
    fi
}

stop
