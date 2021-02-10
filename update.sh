#!/bin/bash

### regelmäßiges Betriebssystem-Update

# description:
#   Dieses Script führt 'apt-get update', 'apt-get upgrade' und 'apt-get dist-upgrade' aus.
#   Es werden Protokolldateien abgelegt, aber nur im Fehlerfall per Mail verschickt.
# author: flo.alt@fa-netz.de
# version: 0.9.2

# see updateconfig to configure this script

source updateconfig

STARTUPD="$(date +%d.%m.%Y-%H:%M)"              # Zeitstempel
LOGFILE="$LOGDIR"/update-"$STARTUPD".log        # Logfile
ERRFILE="$LOGDIR"/error-"$STARTUPD".log		# Error-File
HOST=$(cat /etc/hostname)			# Hostname
ERRORMARKER=0					# Anfangswert für Errormarker

# Voraussetzungen schaffen

if [ ! -d $LOGDIR ]; then mkdir -p $LOGDIR; fi

# Update durchführen

touch $SCRIPTPATH/lastupdate-start

(
echo -e "Protokolldatei vom täglichen Betriebssystem-Update"
echo -e "ausgeführt von $SCRIPTPATH/update.sh\n"
echo -e "Update gestartet $STARTUPD\n"

# Aktualisieren der Paketlisten
echo -e "--== Paketlisten updaten... ==--\n"
apt-get update
ERROR=$?
echo $ERROR > er-upd
echo ""
) | tee $LOGFILE

if [[ $ERROR -eq 0 ]]; then
    echo -e "OK: Paketlisten erfolgreich aktualisiert\n" >> $LOGFILE
 else
    echo -e "FEHLER: Problem beim aktualisiseren der Paketlisten aufgetreten\n" >> $LOGFILE
    echo -e "FEHLER: Problem beim aktualisiseren der Paketlisten aufgetreten\n" >> $ERRFILE
    ((ERRORMARKER++))
fi
(

# Installieren der Updates
echo -e "==-- Upgrade durchführen... --==\n"
apt-get upgrade -y
ERROR=$?
echo ""
) | tee >> $LOGFILE

if [[ $ERROR -eq 0 ]]; then
    echo -e "OK: Updates erfolgreich installiert\n" >> $LOGFILE
 else
    echo -e "FEHLER: Problem beim Installieren der Updates aufgetreten\n" >> $LOGFILE
    echo -e "FEHLER: Problem beim Installieren der Updates aufgetreten\n" >> $ERRFILE
    ((ERRORMARKER++))
fi

(

# Installieren der Dist-Updates
echo -e "--== Dist-Upgrade durchführen... ==--\n"
apt-get dist-upgrade -y
ERROR=$?
echo ""
) | tee >> $LOGFILE

if [[ $ERROR -eq 0 ]]; then
    echo -e "OK: Dist-Upgrades erfolgreich installiert\n" >> $LOGFILE
 else
    echo -e "FEHLER: Problem beim Installieren der Dist-Upgrades aufgetreten\n" >> $LOGFILE
    echo -e "FEHLER: Problem beim Installieren der Dist-Upgrades aufgetreten\n" >> $ERRFILE
    ((ERRORMARKER++))
fi

(

# Autoremove
echo -e "--== Autoremove durchführen... ==--\n"
apt-get autoremove -y
ERROR=$?
echo ""
) | tee >> $LOGFILE

if [[ $ERROR -eq 0 ]]; then
    echo -e "OK: Autoremove erfolgreich durchgeführt\n" >> $LOGFILE
 else
    echo -e "FEHLER: Problem beim Autoremove\n" >> $LOGFILE
    echo -e "FEHLER: Problem beim Autoremove\n" >> $ERRFILE
    ((ERRORMARKER++))
fi

# Update beenden, Logfile, Errorfile
(
echo -e "Update Beendet $(date +%d.%m.%Y-%H:%M)\n"
echo "ENDE: Update wurde beendet"
) | tee >> $LOGFILE

cp "$LOGFILE" $LOGDIR/lastupdate.log			# aktuelles Logfile fürs Monitoring kopieren
find "$LOGDIR"/* -mtime +$LOGTIME -exec rm {} +         # Logdateien, älter als $LOGTIME löschen
touch $SCRIPTPATH/lastupdate-stop                       # Marker-File für Backup-Ende setzen

if [[ "$ERRORMARKER" -gt 0 ]]; then
    echo "Error-Log wird gebaut und verschickt..."
    echo -e "\n\nHier das Logfile:\n" >> $ERRFILE
    cat $LOGFILE >> $ERRFILE
    cp $ERRFILE $LOGDIR/lasterror.log                   # aktuelles Errorfile fürs Monitoring kopieren
    cat $ERRFILE | mail -s "ERROR: APT update auf $HOST bei $CUSTOMER" $SENDTO
    exit 1
 else
    exit 0
fi
