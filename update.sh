#!/bin/bash

### regelmäßiges Betriebssystem-Update

# description:
#   Dieses Script führt 'apt-get update', 'apt-get upgrade' und 'apt-get dist-upgrade' aus.
#   Es werden Protokolldateien abgelegt, aber nur im Fehlerfall per Mail verschickt.
#
#   Konfiguration: siehe Datei 'updateconfig'
#
# author: flo.alt@fa-netz.de
# version: 1.0.0


# Configfile einlesen:
SCRIPTPATH=$(dirname "$(readlink -e "$0")")
source $SCRIPTPATH/updateconfig



# Feste Variablen

STARTUPD="$(date +%d.%m.%Y-%H:%M)"              # Zeitstempel
LOGFILE="$LOGDIR"/update-"$STARTUPD".log        # Logfile
ERRFILE="$LOGDIR"/error-"$STARTUPD".log		# Error-File
HOST=$(cat /etc/hostname)			# Hostname
ERRORMARKER=0					# Anfangswert für Errormarker
ERRTMP1=/tmp/errfile1		# temp. Error-File für Update
ERRTMP2=/tmp/errfile2		# temp. Error-File für Upgrade
ERRTMP3=/tmp/errfile3		# temp. Error-File für Dist-Upgrade
ERRTMP4=/tmp/errfile4		# temp. Error-File für Autoremove


# Funktion: Errorcheck

errorcheck() {
	if [[ ! -s $1 ]]; then
	    echo -e "\nOK: $2 erfolgreich durchgeführt\n" >> $LOGFILE
	 else
	    echo -e "\nFEHLER: Problem beim $2 aufgetreten\n" >> $LOGFILE
	    echo -e "\nFEHLER: Problem beim $2 aufgetreten\n" >> $ERRFILE
	    cat $1 >> $ERRFILE
	    ((ERRORMARKER++))
	fi
	rm $1
}



### Voraussetzungen schaffen

if [ ! -d $LOGDIR ]; then mkdir -p $LOGDIR; fi
touch $SCRIPTPATH/lastupdate-start

# alte errortemp-files löschen
touch /tmp/errfile
VAR1="$(ls /tmp/errfile*)"
for i in "$VAR1"; do rm $i; done

# Logfile erstellen

(
echo -e "Protokolldatei vom täglichen Betriebssystem-Update"
echo -e "ausgeführt von $SCRIPTPATH/update.sh\n"
echo -e "Update gestartet $STARTUPD\n"
) | tee > $LOGFILE




### Update durchführen

# Aktualisieren der Paketlisten
echo -e "--== Paketlisten updaten... ==--\n" >> $LOGFILE
apt-get update >> $LOGFILE 2>> $ERRTMP1
errorcheck $ERRTMP1 "Aktualisieren der Paketlisten"


# Installieren der Updates
echo -e "==-- Upgrade durchführen... --==\n" >> $LOGFILE
apt-get upgrade -y >> $LOGFILE 2>> $ERRTMP2
# apt-get install FehlerProvozieren -y >> $LOGFILE 2>> $ERRTMP2
errorcheck $ERRTMP2 "Installieren der Upgrades"


# Installieren der Dist-Updates
echo -e "--== Dist-Upgrade durchführen... ==--\n" >> $LOGFILE
apt-get dist-upgrade -y >> $LOGFILE 2>> $ERRTMP3
errorcheck $ERRTMP3 "Installieren der Dist-Upgrades"


# Autoremove
echo -e "--== Autoremove durchführen... ==--\n" >> $LOGFILE
apt-get autoremove -y >> $LOGFILE 2>> $ERRTMP4
errorcheck $ERRTMP4 "Autoremove"




### Update beenden, Logfile, Errorfile

(
echo -e "Update Beendet $(date +%d.%m.%Y-%H:%M)\n"
echo "ENDE: Update wurde beendet"
) | tee >> $LOGFILE


# Logfiles managen
cp "$LOGFILE" $LOGDIR/lastupdate.log			# aktuelles Logfile fürs Monitoring kopieren
find "$LOGDIR"/* -mtime +$LOGTIME -exec rm {} +         # Logdateien, älter als $LOGTIME löschen
touch $SCRIPTPATH/lastupdate-stop                       # Marker-File für Backup-Ende setzen

# Error managen und Mail verschicken
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
