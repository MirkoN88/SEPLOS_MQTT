#!/bin/bash

# ================================
#  CONFIGURAZIONE
# ================================
CONFIG=~/SEPLOS_MQTT/config.ini

MQTTHOST=$(grep "MQTTHOST" $CONFIG | awk -F "=" '{print $2}')
TOPIC=$(grep "TOPIC" $CONFIG | awk -F "=" '{print $2}')
MQTTUSER=$(grep "MQTTUSER" $CONFIG | awk -F "=" '{print $2}')
MQTTPASWD=$(grep "MQTTPASWD" $CONFIG | awk -F "=" '{print $2}')
TELEPERIOD=$(grep "TELEPERIOD" $CONFIG | awk -F "=" '{print $2}')
MAXSIZE=$(grep "MAXSIZE" $CONFIG | awk -F "=" '{print $2}')
CELL_MIN_VOLT=$(grep "CELL_MIN_VOLT" $CONFIG | awk -F "=" '{print $2}')
CELL_MAX_VOLT=$(grep "CELL_MAX_VOLT" $CONFIG | awk -F "=" '{print $2}')

LOGNAME=~/SEPLOS_MQTT/BMS_error.log
NOUPFILE=~/SEPLOS_MQTT/nohup.out

mkdir -p ~/SEPLOS_MQTT/

touch "$LOGNAME"
touch "$NOUPFILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') - Script started..." >> $LOGNAME

# ================================
#  FUNZIONE CONTROLLO CELLE
# ================================
checkcellsvoltage() {
    local counter=1
    for CELLV in "$@"; do
        if [ "$CELLV" -lt "$CELL_MIN_VOLT" ] || [ "$CELLV" -gt "$CELL_MAX_VOLT" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Warning: Cell $counter out of range ($CELLV)" >> $LOGNAME
            return 1
        fi
        ((counter++))
    done
    return 0
}

# ================================
#  LOOP PRINCIPALE
# ================================
while true; do

    # Rotazione log
    if [ $(stat -c%s "$LOGNAME") -ge $MAXSIZE ]; then
        mv "$LOGNAME" "$LOGNAME.old"
    fi

    if [ $(stat -c%s "$NOUPFILE") -ge $MAXSIZE ]; then
        cp "$NOUPFILE" "$NOUPFILE.old"
        : > "$NOUPFILE"
    fi

    # Query al BMS
    QUERY=$(~/SEPLOS_MQTT/query_seplos_ha.sh 4201)

    # Estrazione celle
    read -r CELL1 CELL2 CELL3 CELL4 CELL5 CELL6 CELL7 CELL8 CELL9 CELL10 CELL11 CELL12 CELL13 CELL14 CELL15 CELL16 \
        <<< "$(echo $QUERY | awk '{print $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16}')"

    CELLS=($CELL1 $CELL2 $CELL3 $CELL4 $CELL5 $CELL6 $CELL7 $CELL8 $CELL9 $CELL10 $CELL11 $CELL12 $CELL13 $CELL14 $CELL15 $CELL16)

    # Controllo validità celle
    checkcellsvoltage "${CELLS[@]}"
    if [ $? -ne 0 ]; then
        sleep $TELEPERIOD
        continue
    fi

    # Calcolo min/max/diff
    lowcell=$(printf "%s\n" "${CELLS[@]}" | sort -n | head -1)
    highcell=$(printf "%s\n" "${CELLS[@]}" | sort -n | tail -1)
    DIFF=$(echo "$highcell - $lowcell" | bc)

    lowcellnumb=$(printf "%s\n" "${CELLS[@]}" | nl | sort -n -k2 | head -1 | awk '{print $1}')
    highcellnumb=$(printf "%s\n" "${CELLS[@]}" | nl | sort -n -k2 | tail -1 | awk '{print $1}')

    # Estrazione altri parametri
    cell_temp1=$(echo $QUERY | awk '{print $17}')
    cell_temp2=$(echo $QUERY | awk '{print $18}')
    cell_temp3=$(echo $QUERY | awk '{print $19}')
    cell_temp4=$(echo $QUERY | awk '{print $20}')
    env_temp=$(echo $QUERY | awk '{print $21}')
    power_temp=$(echo $QUERY | awk '{print $22}')
    charge_discharge=$(echo $QUERY | awk '{print $23}')
    total_voltage=$(echo $QUERY | awk '{print $24}')
    residual_capacity=$(echo $QUERY | awk '{print $25}')
    soc=$(echo $QUERY | awk '{print $27}')
    cycles=$(echo $QUERY | awk '{print $29}')
    soh=$(echo $QUERY | awk '{print $30}')
    port_voltage=$(echo $QUERY | awk '{print $31}')

    # ================================
    #  COSTRUZIONE JSON
    # ================================
    JSON=$(cat <<EOF
{
"lowest_cell":"Cell $lowcellnumb - $lowcell mV",
"lowest_cell_v":"$lowcell",
"lowest_cell_n":"$lowcellnumb",
"highest_cell":"Cell $highcellnumb - $highcell mV",
"highest_cell_v":"$highcell",
"highest_cell_n":"$highcellnumb",
"difference":"$DIFF",
"cell01":"$CELL1",
"cell02":"$CELL2",
"cell03":"$CELL3",
"cell04":"$CELL4",
"cell05":"$CELL5",
"cell06":"$CELL6",
"cell07":"$CELL7",
"cell08":"$CELL8",
"cell09":"$CELL9",
"cell10":"$CELL10",
"cell11":"$CELL11",
"cell12":"$CELL12",
"cell13":"$CELL13",
"cell14":"$CELL14",
"cell15":"$CELL15",
"cell16":"$CELL16",
"cell_temp1":"$cell_temp1",
"cell_temp2":"$cell_temp2",
"cell_temp3":"$cell_temp3",
"cell_temp4":"$cell_temp4",
"env_temp":"$env_temp",
"power_temp":"$power_temp",
"charge_discharge":"$charge_discharge",
"total_voltage":"$total_voltage",
"residual_capacity":"$residual_capacity",
"soc":"$soc",
"cycles":"$cycles",
"soh":"$soh",
"port_voltage":"$port_voltage"
}
EOF
)

    # ================================
    #  PUBBLICAZIONE MQTT
    # ================================
    mosquitto_pub -h "$MQTTHOST" -u "$MQTTUSER" -P "$MQTTPASWD" \
        -t "$TOPIC" -m "$JSON"

    sleep $TELEPERIOD
done
