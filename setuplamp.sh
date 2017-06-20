#!/bin/bash

function showhelp
{
	echo 'Usage: SetupLAMP.sh [OPTIONS]'
	echo
	echo 'Options are:'
	echo '	--distro		Linux distributuion in use.  "Redhat" or "Ubuntu".  Default is RedHat.'
	echo '  -p | --password		Password for mysql root account.  Only for Ubuntu.'
	echo

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


	esac
	shift
done

# Ensure everything is the same case.
distro=$(echo $distro | tr '[:upper:]' '[:lower:]')
ubuntu=$(echo $ubuntu | tr '[:upper:]' '[:lower:]')
redhat=$(echo $redhat | tr '[:upper:]' '[:lower:]')

if ["$dbpwd" = ""]; then
	echo "Must set a database password!"
	exit 2
fi

if ["$d8user" = ""]; then
	echo no user!
	d8user="drupal"
fi

if ["$d8password" = ""]; then
	d8password="password"
fi

echo D8 User: $d8user, password: $d8password


function ubuntu_install_packages()
{
	echo Setting up CIFS...
	sudo apt-get install -y samba

	echo Setting up LAMP...
	# Set default password for MySQL so install script does not hang in the middle waiting for user input.
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password select $dbpwd"
	sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again select $dbpwd"

	sudo apt-get install -y php7.0 php7.0-mysql php7.0-xml php7.0-cli php-gd php-mbstring php-curl
	sudo apt-get install -y mysql-server mysql-client
	sudo apt-get install -y apache2 libapache2-mod-php7.0

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
	# The items below are customizations for a Drupal dev/stage/prod installation
	echo 'Customizing default LAMP for Drupal dev/stage/prod installation.'
	
	sudo sh -c 'echo "127.0.0.1 dev.loc"   >> /etc/hosts'
	sudo sh -c 'echo "127.0.0.1 prod.loc"  >> /etc/hosts'
	sudo sh -c 'echo "127.0.0.1 stage.loc" >> /etc/hosts'

	sudo a2enmod rewrite

	sudo cp -i 101-dev.conf   /etc/apache2/sites-available
	sudo cp -i 102-stage.conf /etc/apache2/sites-available
	sudo cp -i 103-prod.conf  /etc/apache2/sites-available
		
	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/101-dev.conf
	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/102-stage.conf
	sudo sed -i "s|\/\$HOME|${HOME}|g" /etc/apache2/sites-available/103-prod.conf

	sudo a2ensite 101-dev.conf
	sudo a2ensite 102-stage.conf
	sudo a2ensite 103-prod.conf

	sudo apache2ctl restart
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




