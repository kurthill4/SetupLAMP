#!/bin/bash
#This is the functions library for the setuplamp.sh script.
#Add all needed packages using addPackage, then call installPackages
#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11


#Global variables.
aptPackages=""		#Global list of packages to install
arrScriptsLoaded+=("6581a047-37eb-4384-b15d-14478317fb11")
#repository="https://github.com/kurthill4/miraweb2021"
repository="git@github.com:kurthill4/miraweb2021"

function isScriptLoaded
{
	_result=0	#0=false/Not loaded
	if [[ "${arrScriptsLoaded[@]}" =~ "$1" ]]; then
		_result=1
	fi

	return $_result
}

function scriptsLoaded
{
	for script in "${arrScriptsLoaded[@]}"
	do
		echo $script
	done
}

function showhelp
{
	echo 'Usage: SetupLAMP.sh [OPTIONS]'
	cat setuplamp-help.txt

	exit 1
}

function isInstalled()
{
	packagename=$1

	PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $packagename | grep "install ok installed")

	if [ "" == "$PKG_OK" ]; then
		return 0 #False
	else
		return 1 #Less false
	fi
}

#Adds a single package to list of packages to install
function addPackage
{
	pkg=$1
	status=0

	isInstalled $pkg &> /dev/null
	if [ "$?" == "0" ]; then
		echo "Adding package: $pkg"
		#Add a space between package names
		#[[ "$pkg" != ""  ]] && $pkg="$pkg "
		aptPackages+=" $1"
		
	else
		echo "Package already installed: $pkg"
		status=-1
	fi

	return $status
}

#Adds a space-delimited list of packages to the globla list
function addPackages
{
	packages=$1
	ilist=""	#list of already installed packages

	if [ "$packages" == "" ]; then
		echo "ERROR: addPackages called with empty list!  The Earth will now plunge directly into the Sun."
		exit 1
	fi

	for package in $packages
	do
		addPackage $package
		[[ $? -ne 0 ]] && ilist="$ilist $package"
	done

	echo; echo

	if [ "$ilist" != "" ]; then
		echo "The following packages were already installed:$ilist"
	fi

}

#Installs packages.  Packages must be added to global list via addPackage(s) functions.
#Arg1 = cacheonly setting
function installPackages
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"
	
	_cacheOnly=$1
	_aptArgs=""	#Arguments for the apt command
	_msg="Installing: "

	#Check for cache-only option
	_aptArgs="-y"
	if [ "$_cacheOnly" == "Y" ]; then
		_aptArgs+=" --download-only"
		_msg="Caching: "
	fi

	#Install using global variable that has been put through the addPackage process
	if [ "$nopackages" == "Y" ]; then
		echo "Skipping package installs."
		return 0
	else
		if [ "$aptPackages" != "" ]; then
			echo "$_msg [$aptPackages]"
			sudo apt install $_aptArgs $aptPackages
			local _result=$?
			if [ $_result != 0 ]; then
				echo "Error installing packages."
				exit 1
			fi
		else
			echo "Nothing to install."
		fi
	fi

	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"

}

function installVMWareTools
{
	_vmtools="open-vm-tools-desktop"
	isInstalled $_vmtools &> /dev/null
	if [ "$?" == "0" ]; then
		echo "Installing open VMWare Tools..."
		AddPackage $_vmtools
	else
		echo "open VMWare tools are already installed."
	fi
}

function getPassword()
{
	read -sp "$1" $2
	echo
}

#Must pass password as first argument.
function setupShare()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	if [ "$setupshare" == "Y" ]
	then
		
		pw=$1
		
		for path in "/root/.cifs" "/mnt/backup"
		do
			sudo sh -c "if [ ! -d $path ]; then sudo mkdir $path; fi"
		done

		echo "username=backup" >> sdmiramar-backups
		echo "domain=ics_miramar" >> sdmiramar-backups
		echo "password=$pw" >> sdmiramar-backups
		sudo mv sdmiramar-backups /root/.cifs
		sudo chmod -R 700 /root/.cifs

		if ! grep -q "#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11" /etc/fstab 
		then
			cat fstab | sudo tee -a /etc/fstab
			sudo mount -a
		fi
	else
		echo "Skipping share setup."
	fi

	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"

}

function addHosts()
{
	if ! grep -q "#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11" /etc/hosts
	then
		cat hosts | sudo tee -a /etc/hosts
	fi
}

function addBashAliases()
{
	if [ ! -f ~/.bash_aliases ] || ! grep -q "#SCRIPTID: c177481e-790d-4354-a596-c7aae6b0d152" ~/.bash_aliases
	then
		echo "Copying bash_aliases."
		cat bash_aliases.sh >> ~/.bash_aliases
	fi
}

#This function handles the skipLAMP/LAMPonly flags.
##Arg1 = cacheonly flag
function ubuntuAddPackages()
{
	if [ "$LAMPonly" != "Y" ]; then packages="samba cifs-utils"; fi
	
	if [ "$skipLAMP" != "Y" ]; then	
		packages="$packages php7.4 php7.4-mysql php7.4-xml php7.4-cli php-gd php-mbstring php-curl"
		packages="$packages mysql-server-8.0 mysql-client-8.0 apache2 libapache2-mod-php7.4 php-zip"
		packages="$packages npm php-memcached"

		# Set default password for MySQL so install script does not hang in the middle waiting for user input.
		sudo debconf-set-selections <<< "mysql-server mysql-server/root_password select $dbpwd"
		sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again select $dbpwd"
		cp my.cnf ~/.my.cnf
		sudo sed -i "s|\$PWD|${dbpwd}|g" ~/.my.cnf
		sudo chmod 600 ~/.my.cnf
	fi

	addPackages "$packages"
}

#Install PPA for node.js
function installNodeRepository()
{
	#Default version is "lts"
	if [ "$nodeVersion" == ""]; then $nodeVersion="lts"; fi
	$nodeVersion="setup_$nodeVersion.x"
	$url="https://deb.nodesource.com/$nodeVersion"

	wget -q -O nodePrep.sh $url
	if [ $_ != 0 ]; then
		echo "Error setting up PPA for node.js, therefore surrender."
		exit 1
	fi

	#This avoids a chmod to make the file executable
	cat nodePrep.sh | sudo -E bash -

	rm nodePrep.sh
}

function configure_git
{
	git config --global --bool core.autocrlf false
	git config --global --bool core.safecrlf false
	git config --global --bool core.ignorecase false
	git config --global --bool pull.rebase true
	git config --global --bool color.ui true
	git config --global diff.renames copies
	git config --global alias.a "apply --index"
	git config --global core.excludesfile ~/.gitignore
}

function configure_apache()
{
	wait #debug; ensure nothing else rtunning in BG to avoid overlapped text
	#Ensure server is stopped
	echo "Configuring Apache..."
	sudo apache2ctl stop &> /dev/null
	
	#enable needed modules
	sudo a2enmod ssl rewrite &> /dev/null

	# The items below are customizations for a Drupal dev/stage/prod installation
	echo 'Customizing default LAMP for Drupal dev/stage/prod installation.'
	
	addHosts

	#sudo cp 101-dev.conf   /etc/apache2/sites-available
	#sudo cp 102-stage.conf /etc/apache2/sites-available
	#sudo cp 103-prod.conf  /etc/apache2/sites-available

	#sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/101-dev.conf
	#sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/102-stage.conf
	#sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/103-prod.conf

	#sudo a2ensite 101-dev 102-stage 103-prod &> /dev/null

	self_sign '/etc/apache2' '/CN=*'
	
	sitenum=100
	for site in dev stage prod
	do

		((sitenum++))
		
		conffile=$sitenum-$site.conf
		filename=/etc/apache2/sites-available/$conffile
		servername=$site.loc

		sudo cp env.conf  $filename
		sudo sed -i "s|\/\$home|${HOME}|g" $filename
		sudo sed -i "s|\/\$site|/$site|g" $filename
		sudo sed -i "s|\$servername|$servername|g" $filename
		sudo sed -i "s|\$env|$site|g" $filename
		
		sudo a2ensite $conffile &> /dev/null
		
		
		conffile=$sitenum-$site-ssl.conf
		filename=/etc/apache2/sites-available/$conffile
		servername=$site.loc

		sudo cp env.ssl.conf  $filename
		sudo sed -i "s|\/\$home|${HOME}|g" $filename
		sudo sed -i "s|\/\$site|/$site|g" $filename
		sudo sed -i "s|\$servername|$servername|g" $filename
		sudo sed -i "s|\$env|$site|g" $filename
		
		sudo a2ensite $conffile &> /dev/null

	done
}	

# Generate an SSL certificate (self-signed).
# self_sign(path, subj) where path is the path to create the ssl certificate directory, and subj are certificate parameters (openssl -subj parameter)
function self_sign()
{
	echo "Generating certificate."

	path=$1/ssl
	subj=$2
	privkey=$path/privkey.key
	pubkey=$path/pubkey.crt
	
	sudo sh -c "if [ ! -d $path ]; then mkdir $path; chmod 700 $path; fi"
	sudo sh -c "if [ -f $privkey ]; then rm $privkey; fi"
	sudo sh -c "if [ -f $pubkey ]; then rm $pubkey; fi"
	
	sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 -subj $subj -keyout $privkey -out $pubkey &> /dev/null

	sudo chmod 600 $path/privkey.key $path/pubkey.crt
}

function installComposer()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	echo "Installing Composer..."
	#Install composer version 1 using the --1 option
	#url="https://getcomposer.org/download/latest-1.x/composer.phar"
	url="https://getcomposer.org/installer"
	if [[ "$offline" == "N" ]]; then
		wget -o /dev/null -O installer $url
		local _result=$?
	fi

	if [[ $_result != 0 ]]; then
		if [[ ! -f installer ]]; then
			echo "Error downloading composer installer, and no cached copy exists.  My soul weeps."
			exit 1
		else
			echo "Error downloading composer installer.  Using a cached copy."
		fi
	fi

	if [[ "$cacheonly" == "N" ]]; then
		sudo php ./installer --install-dir=/usr/local/bin --filename=composer --1
		rm installer
		#This may not be needed...
		#sudo chown -R $USER:$USER $HOME/.cache/composer
	fi
	
	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}	

function createProjectDirs()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	echo "Configuring project directories..."
	if [ -d $HOME/web-projects ]; then
		echo "Directory exists!"; jobs
		read -e -N 1 -p 'web-projects directory exists!  Delete? [y/N]? ' ans
		if [[ $ans =~ [Yy] ]]; then		
			echo "Deleting old web-projects."			
			sudo chown -R	$USER:$USER $HOME/web-projects		
			#Don't delete backup directory to keep files symlinks working.
			for env in dev stage prod
			do
				rm -rf $HOME/web-projects/$env
			done

		else
			[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
			return
		fi
	fi

	#Make project directories -- including intermediate directories.
	#Need to create all the way to "files" so we can automate symlink to files later
	if [ ! -d $HOME/web-projects/backup/files ]
	then
		echo "Making project directories"
		mkdir -p $HOME/web-projects/backup/files
	fi

	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"	
}

function configureNPM()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"
	local _projectdir=$1/docroot/themes/custom/sdmc
	pushd $_projectdir
	echo "Running npm install then build."
	npm install > /dev/null 2>&1
	npm run build > /dev/null 2>&1
	popd
	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"	
}

function configureProjects()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	projectdir=$HOME/web-projects
	
	if [ ! -d $projectdir/dev ]
	then
		#Get the dev directory configured fully, then copy it to prog/stage
		# 1. Clone
		# 2. Checkout Production
		# 3. Composer install
		# 4. Configure npm stull
		# 5. Create linked files directory


		#Link files directory to restored archive
		echo "Cloning website repository..."
		git clone $repository $projectdir/dev

		#Now go to tip of production and get all dependencies
		pushd $projectdir/dev > /dev/null
		git checkout Production
		composer install --no-dev > /dev/null 2>&1 & p1=$!
		cd $projectdir/dev/docroot/themes/custom/sdmc
		configureNPM $projectdir/dev & p2=$!
		popd > /dev/null

		#Now symlink the files directory to the files dir in the backup area:
		filedir=$projectdir/dev/docroot/sites/default/files
		[[ -d $filedir ]] && rmdir $filedir
		ln -s $projectdir/backup/files $filedir

		echo "Waiting for composer/npm processes to finish..."
		wait $p1 $p2
	fi

	#Just copy the repository for the stage/prod sites if they do not already exist
	if [ ! -d $projectdir/stage ]; then cp -r $projectdir/dev $projectdir/stage > /dev/null & p1=$!; fi
	if [ ! -d $projectdir/prod ]; then cp -r $projectdir/dev $projectdir/prod  > /dev/null & p2=$!; fi

	echo "Waiting for copies ($p1, $p2) to finish."
	wait $p1 $p2
	echo "Copies finished"

	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}

function configureDrupalSettings()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	local _env

	for _env in dev stage prod
	do
		local _dir="$HOME/web-projects/$_env/docroot/sites/default/settings"
		echo "Creating: $_dir"
		[ ! -d $_dir ] && mkdir $_dir
		
		settingsfile=$_dir/$_env.settings.php

		sed "s|\$d8database|d8dev|" env.settings.php > $settingsfile
		sed -i "s|\$d8user|${d8user}|" $settingsfile
		sed -i "s|\$d8password|${d8password}|" $settingsfile
		sed -i "s|\$env|${_env}|" $settingsfile
	done
	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}


#Restore an archive into the web-projects/backup directory
function restoreArchive
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	local _file=$1
	local _restoredir=$HOME/web-projects/backup

	if [ -f $_file ]
	then
		_file=`realpath $_file`
		pushd $_restoredir > /dev/null
		echo "Restoring: $_file..."
		tar -xzf $_file
		if [ $? != 0 ]; then
			echo "Failed to untar $_file.  I am bereft of all hope."
			popd
			return 5
		fi
		sudo chown -R www-data:www-data $_restoredir/files
		
		#We cannot set the database backup filename here since this is probably
		#being run as a background process

		popd > /dev/null
		
	else
		echo "Archive is gone, like tears in rain..."
		exit 1
	fi

	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}

function initDatabases()
{
	[[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"

	if [ "$dbfilename" = "" ] || [ "$dbfilename" = "UNK" ]; then
		echo "No database to restore."
	else

		echo
		echo "Creating and restoring databases from: $dbfilename..."
		sed "s|\$d8user|${d8user}|" createdb.sql > cdb.sql
		sed -i "s|\$d8password|${d8password}|" cdb.sql
		
		mysql -u root --password=$dbpwd < cdb.sql
		rm cdb.sql

		#gunzip -c $dbfilename > sdmiramar.sql
		echo "Restoring $dbfilename..."	
		mysql -u root --password=$dbpwd d8dev < $dbfilename &> /dev/null & p1=$!
		mysql -u root --password=$dbpwd d8prod < $dbfilename &> /dev/null & p2=$!
		mysql -u root --password=$dbpwd d8stage < $dbfilename &> /dev/null & p3=$!
		
	fi
	[[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}


#------------------------------------------------------------------------------------------------------------------------------
# Functions to automate updating the project to work with OS updates, core updates, etc.
# Things like removing dependencies that don't work with newer core or PHP versions, would go here.
#------------------------------------------------------------------------------------------------------------------------------

#Ubuntu16to18Fixup: Migrate project from old U16 system with PHP7.0 to Ubuntu 18.04/PHP7.2
#Parameter 1: Project name (dev/stage/prod) 
function Ubuntu16to18Fixup()
{
	project=$1
	projectdir=$HOME/web-projects/$1
	projectdb=d8$project
	
	pushd $projectdir > /dev/null
	
	git checkout master; git pull
	composer remove drupal/field_validation
	
	
	popd > /dev/null
}


