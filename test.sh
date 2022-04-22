#!/bin/bash

[[ "${arrScriptsLoaded[@]}" =~ "6581a047-37eb-4384-b15d-14478317fb11" ]] || source functions.sh
[[ "${arrScriptsLoaded[@]}" =~ "b6153465-48c2-440a-964f-427c7aca895c" ]] || source install-docker.sh


scriptsLoaded

for var in dev stage prod
do
    echo $var
done

if [ "Y" = "Y" ]
then
    echo "Yeppers"
fi
