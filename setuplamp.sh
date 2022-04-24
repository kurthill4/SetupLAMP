#!/bin/bash

[[ "${arrScriptsLoaded[@]}" =~ "6581a047-37eb-4384-b15d-14478317fb11" ]] || source functions.sh
[[ "${arrScriptsLoaded[@]}" =~ "c177481e-790d-4354-a596-c7aae6b0d152" ]] || source bash_aliases.sh
[[ "${arrScriptsLoaded[@]}" =~ "b6153465-48c2-440a-964f-427c7aca895c" ]] || source install-docker.sh


#Set global defaults.
#cacheonly will not do any other processing besides caching packages and downloading the composer installer.

#offline		Use only cached information.  Don't wget/curl files, apt/composer  installs must be in the cache, etc.
#				This switch is mutually exclusive with "--cacheonly"
#cacheonly:		Download files only, do not install anything, or make ay configuration changes unless absolutely needed
#				For instance, to cache docker requires adding a repo & key, so that has to happen, but no other config.
#				This switch is mutually exclusive with "--offline"
#dockeronly:	Installs docker only.
#LAMPonly:		Skips all web/database configuration steps.
#noinstall:		Skips apt installs.


ubuntu="ubuntu"
redhat="redhat"
distro=$ubuntu
hostname=$(hostname)
dbfilename="UNK"
skipLAMP="N"
LAMPonly="N"
cacheonly="N"
dockeronly="N"
offline="N"		

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

		--archive )		shift
						archive=$1
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
						LAMPonly="Y"	#cacheonly implies LAMPonly (e.g., no nofig)
						setupshare="N"	#no config
						;;
		
		--dockeronly )	dockeronly="Y"
						LAMPonly="Y"	#dockeronly implies LAMPonly (e.g., no nofig)
						setupshare="N"	#no config
						;;

		--offline )		offline="Y"
						;;

		--noinstall )	noinstall="Y"
						;;

	esac
	shift
done

if [[ "$offline$cacheonly" = "YY" ]]; then
	echo "Cannot cache items when offline.  Discarding Universe and going home."
	exit 1
fi

# Ensure everything is the same case.
distro=$(echo $distro | tr '[:upper:]' '[:lower:]')
ubuntu=$(echo $ubuntu | tr '[:upper:]' '[:lower:]')
redhat=$(echo $redhat | tr '[:upper:]' '[:lower:]')

if [[ "$cacheonly" = "N" ]]; then
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

#The ubunto_install_packages handles the LAMP flags (skipLAMP/LAMPonly)
if [ "$distro" = "$ubuntu" ]; then

	if [ "$noinstall" != "Y" ]; then
		setup_docker_repository
		addPackages "docker-ce docker-ce-cli containerd.io"
		if [[ "$dockeronly" == "Y" ]]; then
			installPackages $cacheonly
			exit 0
		fi

		ubuntuAddPackages
		installPackages $cacheonly
		[[ "$cacheonly" = "Y" ]] && exit 0
	fi

	if [ "$LAMPonly" != "Y" ]; then
		echo "Stopping apache."
		sudo apache2ctl stop &> /dev/null
		configure_git
		setupShare $sharePW
		createProjectDirs
		
		#Old process to restore stuff..
		#cp $dbfilename ~/web-projects/backup

		echo "*** $dbfilename ***"
		if [ -f "$archive" ];then restoreArchive $archive; fi
		
		echo "*** $dbfilename ***"

		initDatabases #& initDatabasesProc=$!
		exit
		installComposer #& installComposerProc=$!
		
		#wait $installComposerProc $initDatabasesProc 
		
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


