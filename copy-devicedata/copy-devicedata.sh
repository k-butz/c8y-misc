#!/bin/bash
####################################################################################
# Script based on: https://github.com/reubenmiller/go-c8y-cli-demos/tree/main/examples/copy-measurements-to-tenant
####################################################################################

WORKERS=5
WORKER_DELAY="100ms"
DATE_FROM="-365d"
DATE_TO="0d"
TIMEOUT="60m"
COPY_TYPES=measurements,events,alarms
DEVICE_TUPLES=""

show_usage () {
    echo ""
    echo "Usage:"
    echo "    $0 [--workers <number>] [--delay <duration>] [--dateFrom <date|relative>] [--dateTo <date|relative>] [--types <measurements,events,alarms>] --device-tuples <query>"
    echo ""
    echo "Example 1: Copy all measurements, events and alarms from devices 123 to 456, and don't prompt for confirmation"
    echo ""
    echo "    $0 --types measurements,events,alarms --device-tuples \"123:456 111:222\" --force"
    echo ""
    echo ""
    echo "Example 2: Copy measurements from all devices (with c8y_IsDevice fragment), but only copy measurements between dates 100 days ago to 7 days ago"
    echo ""
    echo "    $0 --dateFrom -100d --dateTo -7d --types measurements --device-tuples \"123:456 111:222\""
    echo ""
    echo ""
    echo "Arguments:"
    echo ""
    echo "  --device-tuples <string> : A list of device id tuples. Each tuple consists of two Managed object ids in format <source device id>:<destination device id>. Multiple tuples are separated by white-spaces."
    echo "  --workers <int> : Number of concurrent workers to create the measurements"
    echo "  --dateFrom <date|relative_date> : Only include measurements from a specific date"
    echo "  --dateTo <date|relative_date> : Only include measurements to a specific date"
    echo "  --delay <interval> : Delay between after each concurrent worker. This is used to rate limit the workers (to protect the tenant)"
    echo "  --types <csv_list> : CSV list of c8y data types, i.e. measurements,events,alarms"
    echo "  --query <string> : Inventory managed object query"
    echo "  --force|-f : Don't prompt for confirmation"
    echo ""
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --workers)
      WORKERS="$2"
      shift
      shift
      ;;
    
    --dateFrom)
      DATE_FROM="$2"
      shift
      shift
      ;;
    
    --dateTo)
      DATE_TO="$2"
      shift
      shift
      ;;
    
    --delay)
      WORKER_DELAY="$2"
      shift
      shift
      ;;
    
    --types)
      COPY_TYPES="$2"
      shift
      shift
      ;;
    
    --types)
      COPY_TYPES="$2"
      shift
      shift
      ;;

    --device-tuples)
      DEVICE_TUPLES="$2"
      shift
      shift
      ;;
    
    -f|--force)
      export C8Y_SETTINGS_DEFAULTS_FORCE="true"
      shift
      ;;
    
    -h|--help)
      show_usage
      exit 0
      ;;

    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

# set the required session
session_host=$(c8y sessions get -o csv --select host 2>/dev/null)
session_length=${#session_host}
if [ $session_length -eq 0 ]
then
    echo "No session set yet. Please do 'set session' before using the script."
    exit 0
fi


export C8Y_SETTINGS_CACHE_METHODS="GET PUT POST DELETE"
export C8Y_SETTINGS_CACHE_TTL="7d"

echo "Started script with configuration:"
echo " * DATE_FROM = $DATE_FROM"
echo " * DATE_TO = $DATE_TO"
echo " * COPY_TYPES = $COPY_TYPES"
echo " * DEVICE_TUPLES = $DEVICE_TUPLES"
echo " * WORKERS = $WORKERS"
echo " * WORKER_DELAY = $WORKER_DELAY"
echo " * TIMEOUT = $TIMEOUT"


IFS=' ' read -ra ADDR <<< "$DEVICE_TUPLES"
for i in "${ADDR[@]}"; do
    echo -e "\nValidating Device Tuple $i ..."
    device_id_orig=$(echo "$i" | cut -d ":" -f 1)
    device_id_dest=$(echo "$i" | cut -d ":" -f 2)
    
    device_id_orig_count="$( c8y inventory find -n --query "id eq '$device_id_orig'" --orderBy name --pageSize 2 --select id -o csv | grep "^[0-9]\+$" | wc -l | xargs)"
    if [ $device_id_orig_count -eq 0 ]
    then
        echo "Source Device ID $device_id_orig could not be found. Skipping tuple '$i'."
        continue
    fi

    device_id_dest_count="$( c8y inventory find -n --query "id eq '$device_id_dest'" --orderBy name --pageSize 2 --select id -o csv | grep "^[0-9]\+$" | wc -l | xargs)"
    if [ $device_id_dest_count -eq 0 ]
    then
        echo "Target Device ID $device_id_dest could not be found. Skipping tuple '$i'."
        continue
    fi
    echo "Device Tuple '$i' passed validation."
    
    if [[ "$COPY_TYPES" =~ "measurements" ]]; then
        total=$( c8y measurements list -n --device "$device_id_orig" --cache --dateFrom "$DATE_FROM" --dateTo "$DATE_TO" --pageSize 1 --withTotalPages --select statistics.totalPages -o csv )
        echo -e "\nCopying ${total} measurements from device ${device_id_orig} to device ${device_id_dest} ..."
        c8y measurements list --includeAll --device "$device_id_orig" --dateFrom "$DATE_FROM" --dateTo "$DATE_TO" --cache --select '!id,**' --timeout "$TIMEOUT" \
        | c8y measurements create \
            --device "$device_id_dest" \
            --template "input.value" \
            --workers "$WORKERS" \
            --delay "$WORKER_DELAY" \
            --progress \
            --timeout "$TIMEOUT" \
            --abortOnErrors 1000000 \
            --cache \
            -f
    fi

    if [[ "$COPY_TYPES" =~ "events" ]]; then
        total=$( c8y events list -n --device "$device_id_orig" --cache --dateFrom "$DATE_FROM" --dateTo "$DATE_TO" --pageSize 1 --withTotalPages --select statistics.totalPages -o csv )
        echo -e "\nCopying ${total} events from device ${device_id_orig} to device ${device_id_dest} ..."
        c8y events list --includeAll --device "$device_id_orig" --dateFrom "$DATE_FROM" --dateTo "$DATE_TO" --cache --select '!id,!creationTime,!lastUpdated,**' --timeout "$TIMEOUT" \
        | c8y events create \
            --device "$device_id_dest" \
            --template "input.value" \
            --workers "$WORKERS" \
            --delay "$WORKER_DELAY" \
            --progress \
            --timeout "$TIMEOUT" \
            --abortOnErrors 1000000 \
            --cache \
            -f
    fi

    if [[ "$COPY_TYPES" =~ "alarms" ]]; then
        total=$( c8y alarms list -n --device "$device_id_orig" --cache --dateFrom "$DATE_FROM" --dateTo "$DATE_TO" --pageSize 1 --withTotalPages --select statistics.totalPages -o csv )
        echo -e "\nCopying ${total} alarms from device ${device_id_orig} to device ${device_id_dest} ..."
        c8y alarms list --includeAll --device "$device_id_orig" --dateFrom "$DATE_FROM" --dateTo "$DATE_TO" --cache --select '!id,!creationTime,!lastUpdated,**' --timeout "$TIMEOUT" \
        | c8y alarms create \
            --device "$device_id_dest" \
            --template "input.value" \
            --workers "$WORKERS" \
            --delay "$WORKER_DELAY" \
            --progress \
            --timeout "$TIMEOUT" \
            --abortOnErrors 1000000 \
            --cache \
            -f
        fi
done

echo -e "\n=> Script finished\n" 