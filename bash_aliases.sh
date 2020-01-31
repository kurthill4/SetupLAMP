#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11
#Bash Aliases for working with Drupal

#Return the path/filename for the backup that starts with whatever is passed as $1.
#If no parameter is passed, it will return the latest backup.

function getBackupFileName() { ls -t /mnt/backup/$1* 2> /dev/null| head -1; }

#Accepts two parameters.
#Parameter 1: The database name to restore (required)
#Parameter 2: The beginning of the filename (typically a date as yyyymmdd) to restore a specific backup
function restoreDatabase()
{
	restoredir=~/web-projects/backups
	
	#Cannot proceed if I cannot connect to datatabase...
	if [ ! -f ~/.my.cnf ]; then echo "Missing .my.cnf!  Weeping."; exit 1; fi
	#TODO: Read mysql pw if not found in .my.cnf -- read -s -p "MySQL Password: " sqlpwd
	if [ "$1" == "" ]; then echo "restoreDatabase: Missing parameter - database name.  The humanity."; exit 2; fi
	if ! mysql -u root -e 'use $1'; then echo "Database $1 does not exist.  My heart bleeds."; exit 3; fi
	if [ ! -d $restoredir ]; then mkdir $restoredir; fi
	if [ $? -ne 0 ]; then
	  echo "`date`: Missing directory: $projdir"
	  exit 1
	fi
	
	bkfile=$(getBackupFileName $2)
	if [ ! -f $bkfile ]; then echo "No backup file found!  A part of my soul has died."; exit 4; fi
	
	pushd $restoredir &> /dev/null
	echo "Restoring $bkfile"

	sudo rm -rf web
	tar -xf $bkfile
	sudo chown -R www-data web/sites/default/files

	echo "Restoring database to $1..."
	#mysql -u root -p$sqlpwd d8$db < sdmiramar.sql
	mysql $1 < sdmiramar.sql

	pushd ~/web-projects/$db
	../vendor/drush/drush/drush sset system.maintenance_mode 0
	popd &> /dev/null
	popd &> /dev/null

}

function dr()
{
  testpath=${PWD##$HOME/web-projects}
  if [[ $testpath != ${PWD} && $testpath != "" ]]; then
    projectdir=$(echo "$testpath" | awk -F "/" '{print $2}')

    drushpath=$HOME/web-projects/$projectdir/vendor/drush/drush
    drupalpath=$HOME/web-projects/$projectdir/web
    pushd "$drupalpath"
    "$drushpath"/drush "$@"
    popd

  fi;
}

alias gitlog='git log --all --decorate --oneline --graph'
alias gitst='git status'

#End of script chunk
#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11
