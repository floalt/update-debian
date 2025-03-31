#!/bin/bash

### Regular Operating System Update

# Description:
#   This script executes 'apt-get update', 'apt-get upgrade', and 'apt-get dist-upgrade'.
#   If desired, Docker containers will be stopped before the update.
#   Log files are created, but emails are only sent in case of errors.
#
#   Configuration: See the 'update.conf' file.
#
# Author: flo.alt@fa-netz.de
# Version: 2.0


# Variables and Configuration

    SCRIPTPATH=$(dirname "$(readlink -e "$0")")
    source $SCRIPTPATH/aptupdate.conf

    STARTUPD="$(date +%Y-%m-%d_%H-%M-%S)"
    LOGFILE="$LOGDIR/update-$STARTUPD.log"
    ERRFILE="$LOGDIR/error-$STARTUPD.log"
    HOST=$(cat /etc/hostname)


# Functions

    log() {
        echo -e "$(date +%Y-%m-%d_%H-%M-%S) - $1" | tee -a "$LOGFILE"
    }

    errorcheck() {
        if [[ ! -s $1 ]]; then
            log "OK: $2 completed successfully"
        else
            log "ERROR: An issue occurred during $2"
            cat $1 >> "$ERRFILE"
            error_exit
        fi
        rm -f "$1"
    }

    error_exit() {
        start_docker
        logfile_mgmt
        send_errormail
    }

    stop_docker() {
        if [[ -n "${DOCKER_COMPOSE_DIRS[*]}" ]]; then
            log "Updates available, stopping Docker containers..."
            for dir in "${DOCKER_COMPOSE_DIRS[@]}"; do
                if [[ -f "$dir/docker-compose.yml" ]]; then
                    log "Stopping containers in $dir..."
                    docker compose -f "$dir/docker-compose.yml" down || log "WARNING: Failed to stop Docker containers in $dir!"
                else
                    log "ERROR: No docker-compose.yml found in $dir!"
                    error_exit
                fi
            done
        else
            log "INFO: No Docker directories set, skipping container stop."
        fi
    }

    start_docker() {
        if [[ -n "${DOCKER_COMPOSE_DIRS[*]}" ]]; then
            log "Updates completed, restarting Docker containers..."
            for dir in "${DOCKER_COMPOSE_DIRS[@]}"; do
                if [[ -f "$dir/docker-compose.yml" ]]; then
                    log "Starting containers in $dir..."
                    docker compose -f "$dir/docker-compose.yml" up -d || log "WARNING: Failed to start Docker containers in $dir!"
                else
                    log "ERROR: No docker-compose.yml found in $dir!"
                    logfile_mgmt
                    send_errormail
                fi
            done
        else
            log "INFO: No Docker directories set, skipping container start."
        fi
    }

    perform_update() {
        log "Starting upgrade..."
        apt-get upgrade -y >> "$LOGFILE" 2>> /tmp/errfile2
        errorcheck /tmp/errfile2 "installing upgrades"

        log "Starting dist-upgrade..."
        apt-get dist-upgrade -y >> "$LOGFILE" 2>> /tmp/errfile3
        errorcheck /tmp/errfile3 "installing dist-upgrades"

        log "Running autoremove..."
        apt-get autoremove -y >> "$LOGFILE" 2>> /tmp/errfile4
        errorcheck /tmp/errfile4 "autoremove"
    }

    logfile_mgmt() {
        log "INFO: Update completed."
        cp "$LOGFILE" $LOGDIR/lastupdate.log         # Copy current log file for monitoring
        find "$LOGDIR"/* -mtime +$LOGTIME -exec rm {} +  # Delete log files older than $LOGTIME
        touch $SCRIPTPATH/lastupdate-stop            # Create marker file for backup completion
    }

    send_errormail() {
        echo "Building and sending error log..."
        echo -e "\n\nLog file content:\n" >> $ERRFILE
        cat $LOGFILE >> $ERRFILE
        cp $ERRFILE $LOGDIR/lasterror.log          # Copy current error log file for monitoring
        cat $ERRFILE | mail -s "ERROR: APT update on $HOST for $CUSTOMER" $SENDTO
    }


# Execution:

# Initial steps

    touch $SCRIPTPATH/lastupdate-start      # Create marker file for backup start
    if [ ! -d $LOGDIR ]; then mkdir -p $LOGDIR; fi

    export DEBIAN_FRONTEND=noninteractive

    log "Starting system update..."


# Apt update

    log "Updating package lists..."
    apt-get update >> "$LOGFILE" 2>> /tmp/errfile1
    errorcheck /tmp/errfile1 "updating package lists"


# Check if updates are available
    # Install them
    # Start and stop Docker if necessary

    log "Checking for available updates..."
        
    if apt-get -s upgrade | grep -q "^Inst "; then
        stop_docker
        perform_update
        start_docker
    else
        log "INFO: No updates available. Nothing to do here."
    fi


# Final steps

    logfile_mgmt
    echo "All OK"