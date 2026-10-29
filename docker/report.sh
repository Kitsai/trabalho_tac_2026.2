#!/bin/bash
echo "Generating nightly ops report..."
tar czf /tmp/report.tar.gz /home/james/logs/rocketmqlogs 2>/dev/null
echo "done"
