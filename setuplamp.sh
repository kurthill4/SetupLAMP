#!/bin/bash
source functions.lib


#Set global defaults.

ubuntu="ubuntu"
redhat="redhat"
distro=$ubuntu
hostname=$(hostname)
dbfilename="2017-04-12-d8dev-0.sql.gz"
skipLAMP="N"
LAMPonly="N"

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

#The ubunto_install_packages handles the LAMP flags (skipLAMP/LAMPonly)
if [ "$distro" = "$ubuntu" ]; then

	ubuntu_install_packages
	if [ "$LAMPonly" != "Y" ]; then
		sudo apache2ctl stop
		
		echo "Installing composer and restoring databases."
		installComposer & p1=$!
		restoreDatabases & p2=$!
		configure_git
		configure_apache
		wait $p1 $p2 > /dev/null

		configureProjectDirs
		echo "Configuring project directories (Process: $configProjectProcess)"
		wait $configProjectProcess

		configureDrupalSettings
				
		sudo apache2ctl restart
	fi


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


