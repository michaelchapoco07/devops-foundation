#!/bin/bash
#

THRESHOLD=80
USAGE=$(df -h / | grep -v Filesystem | awk '{print$5}' | sed 's/%//')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
		echo "$(date): Disk is at ${USAGE}%" >> /var/log/disk_cleanup.log
	else
		echo "$(date): Disk usage OK (${USAGE}%)" >> /var/log/disk_cleanup.log
	fi
