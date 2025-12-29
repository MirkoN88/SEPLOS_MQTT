#!/bin/bash

LOGFILE=~/SEPLOS_MQTT/BMS_error.log

echo "=== Visualizzazione log BMS ==="
echo "Premi CTRL+C per uscire"
echo ""

tail -f "$LOGFILE"
