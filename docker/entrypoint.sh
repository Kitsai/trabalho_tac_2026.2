#!/bin/sh
set -e

# httpd serves the cosmetic landing page; everything RocketMQ-related runs
# as the unprivileged "rocketmq" user (the real service account -- this is
# the user the CVE-2023-33246 RCE actually lands as).
httpd -k start

su -s /bin/bash rocketmq -c "cd \"\$ROCKETMQ_HOME/bin\" && nohup ./mqnamesrv -c \"\$ROCKETMQ_HOME/conf/namesrv.conf\" > /home/rocketmq/namesrv.log 2>&1 &"

sleep 5

exec su -s /bin/bash rocketmq -c "cd \"\$ROCKETMQ_HOME/bin\" && exec ./mqbroker -n 127.0.0.1:47280 -c \"\$ROCKETMQ_HOME/conf/broker.conf\""
