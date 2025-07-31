set -ex

chmod +x *.sh

cp ./conf/application-prod.yml ./conf/application.yml
cp ./conf/log4j2-example.xml ./conf/log4j2.xml

# #停止服务
if [ x"[@SC_ROUTER_STOP_SCRIPT]" != x"" ];then
  ! sh [@SC_ROUTER_STOP_SCRIPT]
fi

sh [@SC_ROUTER_START_SCRIPT]



