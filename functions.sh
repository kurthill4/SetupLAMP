#!/bin/bash
#This is the functions library for the setuplamp.sh script.
#Add all needed packages using addPackage, then call installPackages
#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11


#Global variables.
aptPackages=""		#Global list of packages to install
arrScriptsLoaded+=("6581a047-37eb-4384-b15d-14478317fb11")

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
	_cacheOnly=$1
	_aptArgs=""	#Arguments for the apt command
	_msg="Installing: 
	"
	#Check for cache-only option
	_aptArgs="-y"
	if [ "$_cacheOnly" == "Y" ]; then
		_aptArgs+=" --download-only"
		_msg="Caching: "
	fi

	#Install using global variable that has been put through the addPackage process
	if [ "$aptPackages" != "" ]; then
		echo "$_msg [$aptPackages]"
		sudo apt install $_aptArgs $aptPackages
	else
		echo "Nothing to install."
	fi

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
	if [ "$setupshare" != "Y" ]; then return; fi
	
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
		packages="$packages php7.4 php7.4-mysql php7.4-xml php7.4-cli php-gd php-mbstring php-curl mysql-server-8.0 mysql-client-8.0 apache2 libapache2-mod-php7.4"

		# Set default password for MySQL so install script does not hang in the middle waiting for user input.
		sudo debconf-set-selections <<< "mysql-server mysql-server/root_password select $dbpwd"
		sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again select $dbpwd"
		cp my.cnf ~/.my.cnf
		sudo sed -i "s|\$PWD|${dbpwd}|g" ~/.my.cnf
		sudo chmod 600 ~/.my.cnf
	fi

	addPackages "$packages"
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

	sudo cp 101-dev.conf   /etc/apache2/sites-available
	sudo cp 102-stage.conf /etc/apache2/sites-available
	sudo cp 103-prod.conf  /etc/apache2/sites-available

	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/101-dev.conf
	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/102-stage.conf
	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/103-prod.conf

	sudo a2ensite 101-dev 102-stage 103-prod &> /dev/null

	#Now the SSL versions
	self_sign '/etc/apache2' '/CN=*'
	
	sitenum=100
	for site in dev stage prod
	do

		((sitenum++))
		conffile=$sitenum-$site-ssl.conf
		filename=/etc/apache2/sites-available/$conffile
		servername=$site.loc

		sudo cp ssl.conf  $filename
		sudo sed -i "s|\/\$HOME|${HOME}|g" $filename
		sudo sed -i "s|\/\$SITE|/$site|g" $filename
		sudo sed -i "s|\$SERVERNAME|$servername|g" $filename
		
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
	echo "Installing Composer..."
	#Install composer version 1 using the --1 option
	#url="https://getcomposer.org/download/latest-1.x/composer.phar"
	url="https://getcomposer.org/installer"
	[[ "$offline" == "N" ]] && wget -o /dev/null -O installer $url
	if [[ $? != 0 && ! -f installer ]]; then
		echo "Error downloading composer installer, and no cached copy exists.  My soul weeps."
		exit 1
	else
		echo "Error downloading composer installer.  Using a cached copy."
	fi

	if [[ "$cacheonly" == "N" ]]; then
		sudo php ./installer --install-dir=/usr/local/bin --filename=composer --1
		rm installer
		sudo chown -R $USER:$USER $HOME/.composer
	fi
}	

function createProjectDirs()
{
	echo "Configuring project directories..."
	if [ -d $HOME/web-projects ]; then
		echo "Directory exists!"; jobs
		read -e -N 1 -p 'web-projects directory exists!  Delete? [y/N]? ' ans
		if [[ $ans =~ [Yy] ]]; then		
			echo "Deleting old web-projects."			
			sudo chown -R	$USER:$USER $HOME/web-projects		
			rm -rf $HOME/web-projects
		else
			return
		fi
	fi

	#Make project directories -- including intermediate directories.
	#Need to create all the way to "files" so we can automate symlink to files later
	echo "Making project directories"
	mkdir -p $HOME/web-projects/backup/web/sites/default/files
	
}

function configureProjects()
{
	projectdir=$HOME/web-projects
	
	echo "Cloning website repositories (dev, stage, prod)..."
	git clone https://github.com/kurthill4/d8 $projectdir/dev

	#Now symlink the files directory to the files dir in the backup area:
	rmdir $projectdir/dev/web/sites/default/files
	ln -s $projectdir/backup/web/sites/default/files $projectdir/dev/web/sites/default/files 	

	#Just copy the repository for the stage/prod sites
	cp -r $projectdir/dev $projectdir/stage > /dev/null & p1=$!
	cp -r $projectdir/dev $projectdir/prod  > /dev/null & p2=$!

	echo "Waiting for git clone processes ($p1, $p2) to finish."
	wait $p1 $p2
	
	echo "Checking out initial repo state and running Composer..."
	pushd . > /dev/null
	#The first will populate the cache...  The others can then go concurrently (in theory...)
	cd $HOME/web-projects/dev;   git checkout initial &> /dev/null; composer install --no-dev
	cd $HOME/web-projects/stage; git checkout initial &> /dev/null; composer install --no-dev &> /dev/null & p1=$!
	cd $HOME/web-projects/prod;  git checkout initial &> /dev/null; composer install --no-dev &> /dev/null & p2=$!
	popd > /dev/null
	echo "Waiting for composer processes ($$p1 and $p2) to finish."
	wait $p1 $p2
}

function configureDrupalSettings()
{
	sed "s|\$d8database|d8dev|" settings.php > $HOME/web-projects/dev/web/sites/default/settings.php
	sed "s|\$d8database|d8prod|" settings.php > $HOME/web-projects/prod/web/sites/default/settings.php
	sed "s|\$d8database|d8stage|" settings.php > $HOME/web-projects/stage/web/sites/default/settings.php

	sed -i "s|\$d8user|${d8user}|" $HOME/web-projects/dev/web/sites/default/settings.php
	sed -i "s|\$d8user|${d8user}|" $HOME/web-projects/prod/web/sites/default/settings.php
	sed -i "s|\$d8user|${d8user}|" $HOME/web-projects/stage/web/sites/default/settings.php

	sed -i "s|\$d8password|${d8password}|" $HOME/web-projects/dev/web/sites/default/settings.php
	sed -i "s|\$d8password|${d8password}|" $HOME/web-projects/prod/web/sites/default/settings.php
	sed -i "s|\$d8password|${d8password}|" $HOME/web-projects/stage/web/sites/default/settings.php
}

function initDatabases()
{

	echo
	echo "Restoring databases from initial state."
	sed "s|\$d8user|${d8user}|" createdb.sql > cdb.sql
	sed -i "s|\$d8password|${d8password}|" cdb.sql
	
	mysql -u root --password=$dbpwd < cdb.sql
	rm cdb.sql

	gunzip -c $dbfilename > sdmiramar.sql	
	mysql -u root --password=$dbpwd d8dev < sdmiramar.sql &> /dev/null & p1=$!
	mysql -u root --password=$dbpwd d8prod < sdmiramar.sql &> /dev/null & p2=$!
	mysql -u root --password=$dbpwd d8stage < sdmiramar.sql &> /dev/null & p3=$!

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


