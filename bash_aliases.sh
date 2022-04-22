#SCRIPTID: c177481e-790d-4354-a596-c7aae6b0d152
#Bash Aliases for working with Drupal

function refreshAlias()
{
	source ~/.bash_aliases
}

#Return the path/filename for the backup that starts with whatever is passed as $1.
#If no parameter is passed, it will return the latest backup.
function getBackupFileName() { ls -t /mnt/backup/$1* 2> /dev/null| head -1; }

#Parameter 1: The beginning of the filename (typically a date as yyyymmdd) to restore a specific backup
#This is deprecated...
function restoreArchiveFromMount()
{
	local filespec=$1
	if [ "$filespec" == "" ]; then filespec=$(date +"%Y%m"); fi
	local restoredir=~/web-projects/backup
	local bkfile=$(getBackupFileName $filespec)

	echo "Backup filename: [$bkfile]"
	if [ "$bkfile" == "" ] || [ ! -f $bkfile ]; then echo "No backup file found!  A part of my soul has died."; return 4; fi	
	
	echo "Restoredir: $restoredir"

	pushd $restoredir > /dev/null

	echo "Restoring $bkfile"
	if [ -d web ]; then sudo mv web oldweb; fi
	tar -xf $bkfile
	if [ $? != 0 ]; then
		echo "Failed to untar $bkfile.  I am bereft of all hope."
		sudo mv oldweb web
		popd
		return 5
	fi
	
	if [ -d oldweb ]; then sudo rm -rf oldweb; fi
	sudo chown -R www-data web/sites/default/files
	popd > /dev/null
}


#Accepts two parameters.
#Parameter 1: 	The project (dev, stage, prod) to restore.
#Parameter 2: 	The beginning of the filename (typically a date as yyyymmdd) to restore a specific backup
#				If nothing is passed, no archive is restored
#				
#NOTE:	Databases begin with drupal version (e.g. d8), so function will concat "d8" to get to database name.
#		This function assumes a valid backup (sdmiramar.sql) exists in the restoredir
#		Typically restoreArchive does this first.
function restoreDatabase()
{
	restoredir=~/web-projects/backup
	db="d8$1"
	
	pushd $restoredir > /dev/null
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
	
	if [ "$2" != "" ]
	then
		restoreArchive $2
		if [ $? != 0 ]; then "Failed to restore archive.  Despair is my only friend."; return 6; fi
	fi
	
	echo "Restoring database to $db..."

	#mysql -u root -p$sqlpwd $db < sdmiramar.sql
	mysql $db < sdmiramar.sql

	if [ -d ~/web-projects/$1 ];
	then
		pushd ~/web-projects/$1 > /dev/null
		sudo rm -rf ~/web-projects/$1/web/sites/default/files
		sudo ln -s ~/web-projects/backup/web/sites/default/files web/sites/default/files
		popd > /dev/null
	fi;

	popd > /dev/null
}

function dr()
{
  #testpath will wither be surrent sub-dir of web-projects, or null (if in
  #web-projects but not a subdirectory) or will be equal to $PWD
  testpath=${PWD##$HOME/web-projects}
  if [[ $testpath != ${PWD} && $testpath != "" ]]; then
    projectdir=$(echo "$testpath" | awk -F "/" '{print $2}')

    drushpath=$HOME/web-projects/$projectdir/vendor/drush/drush
    basepath=$HOME/web-projects/$projectdir
    if [[ -d $basepath/web ]]; then drupalpath=$basepath/web; fi
    if [[ -d $basepath/docroot ]]; then drupalpath=$basepath/docroot; fi

    if [[ "$drupalpath" == "" ]]; then 
    	echo "Can't find web/docroot directory.  There is a gaping hole in my soul."
    	return 2
    fi

    pushd "$drupalpath" > /dev/null
    "$drushpath"/drush "$@"
    popd > /dev/null
  else
	echo "I am not in a web-projects directory.  I feel useless."
    return 1
  fi;
  
}

function mmode()
{
	var="system.maintenance.mode"
	
	if [ "$1" == "" ]; then dr sget $var
	elif [ $1 == 1 ]; then dr sset $var 1
	elif [ $1 == 0 ]; then dr sset $var 0
	else
		echo "That is not a valid mode.  I feel so confused."
		return 1
	fi
}

alias gitlog='git log --all --decorate --oneline --graph'
alias gitst='git status'

#End of script chunk
#SCRIPTID: c177481e-790d-4354-a596-c7aae6b0d152
