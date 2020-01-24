#!/bin/bash

projdir=~/web-projects/backups
backupdir=/mnt/backup

if [ ! -d $projdir ]; then mkdir $projdir; fi
 
pushd $projdir &> /dev/null

if [ $? -ne 0 ]; then
  echo "`date`: Missing directory: $projdir"
  exit 1
fi

#Not needed if config is in ~/.my.cnf
#read -s -p "MySQL Password: " sqlpwd
#echo "You typed: $sqlpwd"
ls
bkfile=`ls -t /mnt/backup | head -1`

echo "`date`: Restoring $backupdir/$bkfile"

sudo rm -rf web
tar -xf $backupdir/$bkfile
sudo chown -R www-data web/sites/default/files

for db in dev stage prod
do
  echo "Restoring d8$db..."
  #mysql -u root -p$sqlpwd d8$db < sdmiramar.sql
  mysql d8$db < sdmiramar.sql

  pushd ~/web-projects/$db
  if [ $? -eq 0 ]; then
	echo "Fetching..."
	git fetch -v
    cd web
    ../vendor/drush/drush/drush sset system.maintenance_mode 0
    popd &> /dev/null
  else
    echo "pushd failed!?"
  fi

done

popd &> /dev/null
