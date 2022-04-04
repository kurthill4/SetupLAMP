#!/bin/bash

[[ "${arrScriptsLoaded[@]}" =~ "6581a047-37eb-4384-b15d-14478317fb11" ]] || source functions.sh
[[ "${arrScriptsLoaded[@]}" =~ "c177481e-790d-4354-a596-c7aae6b0d152" ]] || source bash_aliases.sh
[[ "${arrScriptsLoaded[@]}" =~ "b6153465-48c2-440a-964f-427c7aca895c" ]] || source install-docker.sh


#Set global defaults.
#cacheonly will not do any other processing besides caching packages and downloading the composer installer.

ubuntu="ubuntu"
redhat="redhat"
distro=$ubuntu
hostname=$(hostname)
dbfilename="2017-04-12-d8dev-0.sql.gz"
skipLAMP="N"
LAMPonly="N"
cacheonly="N"
dockeronly="N"	

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

		--setupshare )	setupshare="Y"
						getPassword "Enter password for backup share: " sharePW
						;;

		--cacheonly )	cacheonly="Y"
						;;
		
		--dockeronly )	dockeronly="Y"
						;;

	esac
	shift
done

# Ensure everything is the same case.
distro=$(echo $distro | tr '[:upper:]' '[:lower:]')
ubuntu=$(echo $ubuntu | tr '[:upper:]' '[:lower:]')
redhat=$(echo $redhat | tr '[:upper:]' '[:lower:]')

if [[ "$cacheonly" = "" ]]; then
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
fi

if [[ "$dockeronly" == "Y" ]]; then
	setup_docker_repository
	addPackages "docker-ce docker-ce-cli containerd.io"
	installPackages $cacheonly
	exit 0
fi

#The ubunto_install_packages handles the LAMP flags (skipLAMP/LAMPonly)
if [ "$distro" = "$ubuntu" ]; then

	ubuntu_install_packages $cacheonly
	[[ "$cacheonly" = "Y" ]] && exit 0

	if [ "$LAMPonly" != "Y" ]; then
		echo "Stopping apache."
		sudo apache2ctl stop &> /dev/null
		configure_git
		setupShare $sharePW
		createProjectDirs
		cp sdmiramar.sql ~/web-projects/backup
		restoreArchive & restoreArchiveProc=$!
		installComposer & installComposerProc=$!
		initDatabases & initDatabasesProc=$!
		wait $installComposerProc $initDatabasesProc 
		
		configureProjects & configProjectsProc=$!
		
		wait $configProjectsProc $restoreDatabaseProc
		restoreDatabase prod & restoreDatabaseProc=$!
		configureDrupalSettings
		configure_apache
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


