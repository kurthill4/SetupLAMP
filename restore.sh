#!/bin/bash
bkupdate=$(date +"%Y%m%d" -d "- 1 day")
bkupdir=$HOME"/Desktop/Website Backups"
site=$HOME"/web-projects/dev"
site='/var/www/www.sdmiramar.edu'

function restore_files
{
	echo Restoring files...
	sudo tar -xf "$bkupdir"/$files -C "$site"/web/sites/default
	sudo chown -R khill:www-data "$site"/web/sites/default/files
	chmod -R ug+w "$site"/web/sites/default/files
}

function restore_database
{
	echo Restoring database...
	gunzip -c "$bkupdir"/$database | mysql -u root -p $dbname
}


files=$bkupdate-0-files.tar.gz
database=$bkupdate-0-d8dev.sql.gz
dbname=sdmiramar

restore_files
restore_database

pushd
cd $site && git checkout dev && git pull && composer install
cd web
../vendor/drush/drush/drush cr
popd



