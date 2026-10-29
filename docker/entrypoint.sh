#!/bin/sh
set -e

# httpd serves the cosmetic landing page; everything RocketMQ-related runs
# as the unprivileged "james" user (uid/gid same as the upstream image's
# default "rocketmq" user -- just renamed to fit the theme). No crond
# anymore -- the privesc path no longer depends on cron.
httpd -k start

su -s /bin/bash james -c "cd \"\$ROCKETMQ_HOME/bin\" && nohup ./mqnamesrv -c \"\$ROCKETMQ_HOME/conf/namesrv.conf\" > /home/james/namesrv.log 2>&1 &"

sleep 5

exec su -s /bin/bash james -c "cd \"\$ROCKETMQ_HOME/bin\" && exec ./mqbroker -n 127.0.0.1:47280 -c \"\$ROCKETMQ_HOME/conf/broker.conf\""
