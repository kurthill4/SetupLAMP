#SCRIPTID: 6581a047-37eb-4384-b15d-14478317fb11
#Bash Aliases for working with Drupal

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

alias gitlog='git log --all --decorate --oneline --graph'
alias gitst='git status'

