#!/bin/bash

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
		return 0
	else
		return 1
	fi
}

function installVMWareTools
{
	vmtools="open-vm-tools-desktop"
	isInstalled $vmtools &> /dev/null
	if [ "$?" == "0" ]; then
		echo "Installing open VMWare Tools..."
		sudo apt-get install $vmtools
	else
		echo "open VMWare tools are already installed."
	fi
}

function getPassword()
{
	read -sp "$1" $2
	echo
}

function setupshare()
{
	getPassword "Enter password for backup share: " pw
	
	for path in "/root/.cifs" "/mnt/backup"
	do
		sudo sh -c "if [ ! -d $path ]; then sudo mkdir $path; fi"
	done

	echo "username=backup" >> sdmiramar-backups
	echo "domain=ics_miramar" >> sdmiramar-backups
	echo "password=$pw" >> sdmiramar-backups
	sudo mv sdmiramar-backups /root/.cifs
	sudo chmod -R 700 /root/.cifs

	if ! grep "#CIFS Share for website backups." /etc/fstab 
	then
		echo "#CIFS Share for website backups." | sudo tee -a /etc/fstab > /dev/null
		echo "//vm-fs-01.ics.sdmiramar.net/Backups/www/sdmiramar /mnt/backup/ cifs credentials=/root/.cifs/sdmiramar-backups 0 0" | sudo tee -a /etc/fstab > /dev/null
	fi
	
	sudo mount -a

	exit 1
}


ubuntu="ubuntu"
redhat="redhat"
distro=$ubuntu
hostname=$(hostname)
dbfilename="2017-04-12-d8dev-0.sql.gz"

while [ "$1" != "" ]; do
	case $1 in
		
		--distro )		shift
						distro=$1
						;;

		-p )			getPassword "Enter mysql root password: " dbpwd
						;;
		
		--password )	shift
						dbpwd=$1
						;;
					

		-? | --help )	showhelp
						;;

		--d8user )		shift
						d8user=$1
						;;

		--d8password )	shift
						d8password=$1
						;;

		--dbfilename )	shift
						dbfilename=$1
						;; 
	
		--LAMPonly )	LAMPonly="Y"
						;;

		--skipLAMP )	skipLAMP="Y"
						;;

		--hostname )	shift
						hostname=$1
						;;

		--setupshare )	setupshare
						;;
				


	esac
	shift
done

# Ensure everything is the same case.
distro=$(echo $distro | tr '[:upper:]' '[:lower:]')
ubuntu=$(echo $ubuntu | tr '[:upper:]' '[:lower:]')
redhat=$(echo $redhat | tr '[:upper:]' '[:lower:]')

if [ "$dbpwd" = "" ]; then
	echo "Must set a database password!"
	exit 2
fi

if [ "$d8user" = "" ]; then
	echo no user!
	d8user="drupal"
fi

if [ "$d8password" = "" ]; then
	d8password="password"
fi

echo D8 User: $d8user, password: $d8password


function ubuntu_install_packages()
{
	echo Setting up CIFS...
	sudo apt-get install -y samba cifs-utils

	echo Setting up LAMP...
	# Set default password for MySQL so install script does not hang in the middle waiting for user input.
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password select $dbpwd"
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again select $dbpwd"

	sudo apt-get install -y php7.2 php7.2-mysql php7.2-xml php7.2-cli php-gd php-mbstring php-curl
	sudo apt-get install -y mysql-server mysql-client
	sudo apt-get install -y apache2 libapache2-mod-php7.2

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
	#enable needed modules
	sudo a2enmod ssl rewrite

	# The items below are customizations for a Drupal dev/stage/prod installation
	echo 'Customizing default LAMP for Drupal dev/stage/prod installation.'
	
	sudo sh -c 'echo "127.0.0.1 dev.loc"   >> /etc/hosts'
	sudo sh -c 'echo "127.0.0.1 prod.loc"  >> /etc/hosts'
	sudo sh -c 'echo "127.0.0.1 stage.loc" >> /etc/hosts'


	sudo cp -i 101-dev.conf   /etc/apache2/sites-available
	sudo cp -i 102-stage.conf /etc/apache2/sites-available
	sudo cp -i 103-prod.conf  /etc/apache2/sites-available

	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/101-dev.conf
	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/102-stage.conf
	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/103-prod.conf

	sudo a2ensite 101-dev 102-stage 103-prod 

	#Now the SSL versions
	sitenum=100
	for site in dev stage prod
	do
		echo "Setting up: -- $site --"
		((sitenum++))
		filename=/etc/apache2/sites-available/$sitenum-$site-ssl.conf
		servername=$site.loc

		echo "Server Name: $servername"
		echo "Config File: $filename"

		sudo cp -i ssl.conf  $filename
		sudo sed -i "s|\/\$HOME|${HOME}|g" $filename
		sudo sed -i "s|\/\$SITE|/$site|g" $filename
		sudo sed -i "s|\$SERVERNAME|$servername|g" $filename
		
		sudo a2ensite $filename

	done

	self_sign '/etc/apache2' '/CN=*'
	sudo apache2ctl restart
}	

# Generate an SSL certificate (self-signed).
# self_sign(path, subj) where path is the path to create the ssl certificate directory, and subj are certificate parameters (openssl -subj parameter)
function self_sign()
{
	echo Generating certificate.

	path=$1/ssl
	subj=$2
	privkey=$path/privkey.key
	pubkey=$path/pubkey.crt

	sudo sh -c 'if [ ! -d $path ]; then mkdir $path; chmod 700 $path; fi'
	sudo sh -c "if [ -f $privkey ]; then rm $privkey; fi"
	sudo sh -c "if [ -f $pubkey ]; then rm $pubkey; fi"
	
	sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 -subj $subj -keyout $privkey -out $pubkey

	sudo chmod 600 $path/privkey.key $path/pubkey.crt
}

function install_composer()
{
	wget https://getcomposer.org/installer

	sudo php ./installer --install-dir=/usr/local/bin --filename=composer
	rm installer

	sudo chown -R $USER:$USER $HOME/.composer
}	


function configure_project_dirs()
{
	if [ -d $HOME/web-projects ]; then
		read -e -N 1 -p 'web-projects directory exists!  Delete? [y/N]? ' ans
		if [[ $ans =~ [Yy] ]]; then		
			echo "Deleting old web-projects."			
			sudo chown -R	$USER:$USER $HOME/web-projects		
			rm -rf $HOME/web-projects
		else
			return
		fi
	fi
	
	mkdir $HOME/web-projects

	git clone http://github.com/kurthill4/d8 $HOME/web-projects/dev
	git clone http://github.com/kurthill4/d8 $HOME/web-projects/stage
	git clone http://github.com/kurthill4/d8 $HOME/web-projects/prod

	pushd .
	cd $HOME/web-projects/dev;   git checkout initial;	composer install
	cd $HOME/web-projects/stage; git checkout initial;	composer install
	cd $HOME/web-projects/prod;  git checkout initial;	composer install
	popd

}

function configure_drupal_settings()
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

function restoreDatabases()
{

	echo
	echo "Restoring databases from initial state."
	sed "s|\$d8user|${d8user}|" createdb.sql > cdb.sql
	sed -i "s|\$d8password|${d8password}|" cdb.sql
	
	mysql -u root --password=$dbpwd < cdb.sql
	rm cdb.sql

	gunzip -c $dbfilename | mysql -u root --password=$dbpwd d8dev
	gunzip -c $dbfilename | mysql -u root --password=$dbpwd d8prod
	gunzip -c $dbfilename | mysql -u root --password=$dbpwd d8stage
}




if [ "$distro" = "$ubuntu" ]; then

	if [ "$LAMPonly" == "Y" ]; then
		echo "Installing LAMP stack only."		
		ubuntu_install_packages
	else

		if [ "$skipLAMP" != "Y" ]; then
			echo "Full d8dev install."
			ubuntu_install_packages
		fi


		if [ "$skipProjectSetup" != "Y" ]; then
			install_composer
			configure_project_dirs
			configure_apache
			configure_git
		fi


		configure_drupal_settings
		restoreDatabases
	fi

	#Get drush and drupal via composer...
	#wget https://ftp.drupal.org/files/projects/drupal-8.2.7.tar.gz
	#wget http://files.drush.org/drush.phar
	#tar -xvf drupal-8.2.7.tar.gz

fi

if [ "$distro" = "$redhat" ]; then
	echo Disabling SELinux Enforcement cuz it sux.
	echo 0 > /selinux/enforce

	yum -y install php-xsl php-mysql php-soap

	/sbin/chkconfig httpd on
	/sbin/chkconfig mysqld on
	/sbin/service mysqld start
	/sbin/service httpd start

	/usr/bin/mysqladmin -u root password $dbpwd
	/usr/bin/mysqladmin -u root -h $hostname password $dbpwd
	

fi




