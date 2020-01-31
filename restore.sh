#Return the path/filename for the backup that starts with whatever is passed as $1.
#If no parameter is passed, it will return the latest backup.

function refreshAlias()
{
	source ~/.bash_aliases
}

function getBackupFileName() { ls -t /mnt/backup/$1* 2> /dev/null| head -1; }

#Accepts two parameters.
#Parameter 1: The project (dev, stage, prod) to restore.
#Parameter 2: The beginning of the filename (typically a date as yyyymmdd) to restore a specific backup
#NOTE:   Databases begin with drupal version (e.g. d8), so function will concat "d8" to get to database name.
function restoreDatabase()
{
	restoredir=~/web-projects/backups
	db="d8$1"
	
	#Cannot proceed if I cannot connect to datatabase...
	if [ ! -f ~/.my.cnf ]; then echo "Missing .my.cnf!  Weeping."; return 1; fi
	#TODO: Read mysql pw if not found in .my.cnf -- read -s -p "MySQL Password: " sqlpwd
	if [ "$1" == "" ]; then echo "restoreDatabase: Missing parameter - database name.  The humanity."; return 2; fi
	if ! mysql -u root -e "use $db"; then echo "Database $db does not exist.  My heart bleeds."; return 3; fi
	if [ ! -d $restoredir ]; then mkdir $restoredir; fi
	if [ $? -ne 0 ]; then
	  echo "`date`: Missing directory: $projdir"
	  exit 1
	fi
	
	bkfile=$(getBackupFileName $2)
	echo "Backup filename: [$bkfile]"
	if [ "$bkfile" == "" ] || [ ! -f $bkfile ]; then echo "No backup file found!  A part of my soul has died."; return 4; fi	
	
	pushd $restoredir &> /dev/null
	echo "Restoring $bkfile"
	sudo rm -rf web
	tar -xf $bkfile
	sudo chown -R www-data web/sites/default/files

	echo "Restoring database to $db..."
	#mysql -u root -p$sqlpwd $db < sdmiramar.sql
	mysql $db < sdmiramar.sql

	if [ -d ~/web-projects/$1 ];
	then
		pushd ~/web-projects/$1 > /dev/null
		sudo rm -rf ~/web-projects/$1/web/sites/default/files
		sudo ln -s ~/web-projects/backups/web/sites/default/files web/sites/default/files
		dr cr
		dr sset system.maintenance_mode 0
		popd > /dev/null
	fi;
			

	popd &> /dev/null

}

