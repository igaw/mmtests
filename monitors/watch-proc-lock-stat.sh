#!/bin/bash
while [ 1 ]; do
	echo time: `date +%s`
	cat /proc/lock_stat
	sleep $MONITOR_UPDATE_FREQUENCY
done
