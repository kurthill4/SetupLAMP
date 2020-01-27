#!/bin/bash
source functions.lib


#Set global defaults.

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

echo "Creating bash aliases..."
addBashAliases


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
			configure_apache &
			configure_git &
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


