#!/bin/bash

# Source external configuration variables to populate the relevant variables.
# Be sure to modify p4proxy-cache-clean.env to suit your environment.
#   Variables include:
#     DAYS_OLD (count of days)
#     P4P_DIR (path)
#     LOG_FILE (path)
#     HOST_LOCATION (geographic place)
source ./p4proxy-cache-clean.env

# Locally-defined configuration variables
SCRIPT_PATH="$(realpath "$0")"

# Stripping trailing slash (if it exists) from $P4P_DIR
P4P_DIR=${P4P_DIR%/}

# Function to add a timestamp to log entries
log_with_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# Function to explain usage, if the script arguments are wrong for any reason
display_usage() {
    echo "Usage: p4proxy-cache-clean.sh {-p|--purge | -t|--test} {-r|--report | -n|--noreport}"
    echo
    echo "  -p, --purge      Take full action, deleting all files."
    echo "  -t, --test       Delete no files, but display what would happen."
    echo "  -r, --report     Send the notification as configured (email, AWS SNS, etc.)."
    echo "  -n, --noreport   Send no notification, but display and log the results."
    echo
    exit 1
}

# Check that there are 2 valid arguments: $1 = (-p, --purge, -t, or --test), $2 = (-r, --report, -n, or --noreport)
if [[ $# -ne 2 ]]; then
    display_usage
fi
if [[ "$1" != "-p" && "$1" != "--purge" && "$1" != "-t" && "$1" != "--test" ]]; then
    display_usage
fi
if [[ "$2" != "-r" && "$2" != "--report" && "$2" != "-n" && "$2" != "--noreport" ]]; then
    display_usage
fi


# Compress the previous log file (if it exists)
if [ -f "$LOG_FILE" ]; then
    mv "$LOG_FILE" "${LOG_FILE}_$(date '+%Y%m%d%H%M%S').log"
    gzip "${LOG_FILE}_$(date '+%Y%m%d%H%M%S').log"
fi

# Begin script logging
if [[ "$1" == "-p" || "$1" == "--purge" ]]; then
    # Purge mode
    log_with_timestamp "====================================================="
    log_with_timestamp "== Beginning Perforce Proxy cache cleanup on $HOSTNAME",
    log_with_timestamp "== the P4Proxy server in $HOST_LOCATION".
    log_with_timestamp "== This script lives on that host, in the location"
    log_with_timestamp "== ($SCRIPT_PATH)."
    log_with_timestamp "====================================================="
elif [[ "$1" == "-t" || "$1" == "--test" ]]; then
    # Test mode
    log_with_timestamp "TEST RUN (REPORT ONLY): ====================================================="
    log_with_timestamp "TEST RUN (REPORT ONLY): == Beginning Perforce Proxy cache cleanup on $HOSTNAME",
    log_with_timestamp "TEST RUN (REPORT ONLY): == the P4Proxy server in $HOST_LOCATION".
    log_with_timestamp "TEST RUN (REPORT ONLY): == This script lives on that host, in the location"
    log_with_timestamp "TEST RUN (REPORT ONLY): == ($SCRIPT_PATH)."
    log_with_timestamp "TEST RUN (REPORT ONLY): ====================================================="
else
    display_usage
fi

# Calculate starting percentage utilization and total volume size
STARTING_USAGE=$(df -h "$P4P_DIR" | awk 'NR==2{print $5}')
TOTAL_VOLUME_SIZE=$(df -h "$P4P_DIR" | awk 'NR==2{print $2}')
if [[ "$1" == "-p" || "$1" == "--purge" ]]; then
    # Purge mode
    log_with_timestamp "$P4P_DIR/, a $TOTAL_VOLUME_SIZE volume, is $STARTING_USAGE used before cleanup."
elif [[ "$1" == "-t" || "$1" == "--test" ]]; then
    # Test mode
    log_with_timestamp "TEST RUN (REPORT ONLY): $P4P_DIR/, a $TOTAL_VOLUME_SIZE volume, is $STARTING_USAGE used before cleanup."
else
    display_usage
fi

# Calculate starting total size of files
STARTING_TOTAL_FILES=$(find "$P4P_DIR" -type f | wc -l)
STARTING_TOTAL_GB=$(du -sh --block-size=G "$P4P_DIR" | cut -f1 | sed 's/G//g')
if [[ "$1" == "-p" || "$1" == "--purge" ]]; then
    # Purge mode
    log_with_timestamp "$P4P_DIR/ has $(echo $STARTING_TOTAL_FILES | awk '{printf "%'\''d\n", $1}') files consuming $(echo $STARTING_TOTAL_GB | awk '{printf "%'\''d\n", $1 + 0.5}') GB before cleanup."
elif [[ "$1" == "-t" || "$1" == "--test" ]]; then
    # Test mode
    log_with_timestamp "TEST RUN (REPORT ONLY): $P4P_DIR/ has $(echo $STARTING_TOTAL_FILES | awk '{printf "%'\''d\n", $1}') files consuming $(echo $STARTING_TOTAL_GB | awk '{printf "%'\''d\n", $1 + 0.5}') GB before cleanup."
else
    display_usage
fi

# Delete files
if [[ "$1" == "-p" || "$1" == "--purge" ]]; then
    # Purge mode
    log_with_timestamp "============== Beginning file deletion =============="
    log_with_timestamp "Deleting files from $P4P_DIR not accessed for $DAYS_OLD days or more."
    find "$P4P_DIR" -mindepth 2 -type f -atime +$DAYS_OLD -exec rm -f {} \; 2>> "$LOG_FILE"
    log_with_timestamp "Deleting $P4P_DIR/pdb.lbr to avoid transfer scheduling conflicts."
    rm -f $P4P_DIR/pdb.lbr

elif [[ "$1" == "-t" || "$1" == "--test" ]]; then
    # Test mode
    echo "TEST RUN (REPORT ONLY): ============== Beginning file deletion ==============" | tee -a "$LOG_FILE"
    echo "TEST RUN (REPORT ONLY): Deleting files from $P4P_DIR not accessed for $DAYS_OLD days or more." | tee -a "$LOG_FILE"
    TEMP_DELETE_SIZE=$(find "$P4P_DIR" -mindepth 2 -type f -atime +$DAYS_OLD -exec du -k {} + | tee -a "$LOG_FILE"  | tee >(awk '{sum += $1} END {printf "%.1fG\n", sum / 1024 / 1024}') | awk '{print}')
    echo "TEST RUN (REPORT ONLY): Would delete $TEMP_DELETE_SIZE of files" | tee -a "$LOG_FILE"
    echo "TEST RUN (REPORT ONLY): Would also delete $P4P_DIR/pdb.lbr to avoid transfer scheduling conflicts."
else
    display_usage
fi

# Action results
log_with_timestamp "================== Script Results ==================="
if [[ "$1" == "-p" || "$1" == "--purge" ]]; then
    # Purge mode
    ENDING_TOTAL_FILES=$(find "$P4P_DIR" -type f | wc -l)
    ENDING_TOTAL_GB=$(du -sh --block-size=G "$P4P_DIR" | cut -f1 | sed 's/G//g')
    DELETED_FILES=$((STARTING_TOTAL_FILES - ENDING_TOTAL_FILES))
    FREED_SPACE=$(echo "$STARTING_TOTAL_GB - $ENDING_TOTAL_GB" | bc)
    log_with_timestamp "$(echo $DELETED_FILES | awk '{printf "%'''d\n", $1}') files deleted from $P4P_DIR/, freeing $(echo $FREED_SPACE | awk '{printf "%'''d\n", $1 + 0.5}') GB of space."
else
    # Test mode
    SIMULATED_DELETED_FILES=$(find "$P4P_DIR" -mindepth 2 -type f -atime +$DAYS_OLD | wc -l)
    SIMULATED_FREED_SPACE=$(find "$P4P_DIR" -mindepth 2 -type f -atime +$DAYS_OLD -exec du -k {} + | awk '{sum += $1} END {print sum / 1024 / 1024}')
    log_with_timestamp "TEST RUN (REPORT ONLY): $(echo $SIMULATED_DELETED_FILES | awk '{printf "%'''d\n", $1}') files would be deleted from $P4P_DIR/, freeing $(echo $SIMULATED_FREED_SPACE | awk '{printf "%.1f\n", $1}') GB of space."
fi

# Ending info about percentage use
if [[ "$1" == "-p" || "$1" == "--purge" ]]; then
    ENDING_USAGE=$(df -h "$P4P_DIR" | awk 'NR==2{print $5}')
    log_with_timestamp "$P4P_DIR/, a $TOTAL_VOLUME_SIZE volume, is $ENDING_USAGE used after cleanup."
else
    # Test mode - Simulated ending usage
    SIMULATED_ENDING_GB=$(echo "$STARTING_TOTAL_GB - $SIMULATED_FREED_SPACE" | bc)
    SIMULATED_ENDING_USAGE=$(awk -v total="$TOTAL_VOLUME_SIZE" -v used="$SIMULATED_ENDING_GB" 'BEGIN { printf "%.1f%%", (used / total) * 100 }')
    log_with_timestamp "TEST RUN (REPORT ONLY): $P4P_DIR/, a $TOTAL_VOLUME_SIZE volume, would be $SIMULATED_ENDING_USAGE used after cleanup."
fi

# Ending info about actual use
if [[ "$1" == "-p" || "$1" == "--purge" ]]; then
    log_with_timestamp "$P4P_DIR/ has $(echo $ENDING_TOTAL_FILES | awk '{printf "%'\''d\n", $1}') files consuming $(echo $ENDING_TOTAL_GB | awk '{printf "%'\''d\n", $1 + 0.5}') GB after cleanup."
else
    # Test mode - Simulated ending state
    SIMULATED_REMAINING_FILES=$((STARTING_TOTAL_FILES - SIMULATED_DELETED_FILES))
    SIMULATED_REMAINING_GB=$(echo "$STARTING_TOTAL_GB - $SIMULATED_FREED_SPACE" | bc)
    log_with_timestamp "TEST RUN (REPORT ONLY): $P4P_DIR/ would have $(echo $SIMULATED_REMAINING_FILES | awk '{printf "%'\''d\n", $1}') files consuming $(echo $SIMULATED_REMAINING_GB | awk '{printf "%'\''d\n", $1 + 0.5}') GB after cleanup (simulated).""
fi

# Sending the results via SNS
if [[ "$2" == "-r" || "$2" == "--report" ]]; then
    log_with_timestamp "======= Sending logfile contents via AWS SNS ======="
    SNS_TOPIC_ARN="arn:aws:sns:$AWS_SNS_REGION:$AWS_ACCOUNT:$AWS_SNS_TOPIC_NAME"
    aws --region "$AWS_SNS_REGION" sns publish --topic-arn "$SNS_TOPIC_ARN" --message file://"$LOG_FILE" --subject "$HOST_LOCATION Perforce Proxy cache maintenance log."
fi