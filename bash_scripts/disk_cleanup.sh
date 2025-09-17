#!/bin/bash
#

THRESHOLD=80
USAGE=$(df -h / | grep -v Filesystem | awk '{print$5}' | sed 's/%//')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
  echo "$(date): Disk is at ${USAGE}%" >>/home/michael/disk_cleanup.log
else
  echo "$(date): Disk usage OK (${USAGE}%)" >>/home/michael/disk_cleanup.log
fi
