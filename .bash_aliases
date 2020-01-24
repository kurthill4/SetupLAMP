function dr()
{
  testpath=${PWD##$HOME/web-projects}
  if [[ $testpath != ${PWD} && $testpath != "" ]]; then
    projectdir=$(echo "$testpath" | awk -F "/" '{print $2}')

    drushpath=$HOME/web-projects/$projectdir/vendor/drush/drush
    drupalpath=$HOME/web-projects/$projectdir/web
    pushd "$drupalpath"
    "$drushpath"/drush "$@"
    popd

  fi;
}

