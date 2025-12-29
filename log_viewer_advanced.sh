#!/bin/bash

LOGFILE=~/SEPLOS_MQTT/BMS_error.log

echo -e "\e[36m=== LOG VIEWER BMS (colorato) ===\e[0m"
echo ""

tail -f "$LOGFILE" | awk '
/Warning/ {print "\033[33m" $0 "\033[0m"}
/Error/   {print "\033[31m" $0 "\033[0m"}
!/Warning/ && !/Error/ {print $0}
'
