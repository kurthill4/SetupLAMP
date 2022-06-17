#!/bin/bash
#Installs the Docker engine.
#requires functions.sh
#SCRIPTID: b6153465-48c2-440a-964f-427c7aca895c

arrScriptsLoaded+=("b6153465-48c2-440a-964f-427c7aca895c")
[[ "${arrScriptsLoaded[@]}" =~ "6581a047-37eb-4384-b15d-14478317fb11" ]] || source functions.sh

#TODO: Is this even needed?
function pre_install 
{
    echo "Depricated function called: pre_install in install-docker.sh"
    exit

    #This was the original set of packages:
    #apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release cifs-utils git

    #Minimalist approach
    addPackages "ca-certificates curl gnupg lsb-release"
}

#TODO: 
function setup_docker_repository 
{
    [[ "$debug" == "Y" ]] && echo "*** Entering function: ${FUNCNAME[0]}"
    local _result=0

    if [ "$nopackages" == "Y" ]; then
        echo "Skipping docker install (nopackages is TRUE)"
        return 0
    fi

    echo Installing Docker Repositories.

    #Add git repository to get the very latest version of git.
    #This will automatically update the apt database.
    #add-apt-repository ppa:git-core/ppa

    #Add Docker's GPG Key
    file=/usr/share/keyrings/docker-archive-keyring.gpg
    if [ -f "$file" ]; then
        echo "Docker GPG key already exists."
    else
        url="https://download.docker.com/linux/ubuntu/gpg"
        #curl -fsSL $url | sudo gpg --dearmor -o $file
        
        if [[ "$offline" == "N" ]]; then
            wget -O docker-key.gpg -o /dev/null $url
            [[ $? -ne 0 ]] && echo "Unable to download Docker GPG key.  Looking for cached key..."
        fi

        if [[ ! -f docker-key.gpg ]]; then
            echo "Missing Docker GPG key file.  Extinguishing dinosaurs..."
            exit 1
        fi

        sudo gpg --dearmor -o $file docker-key.gpg
    fi

    #Add the repositories
    file=/etc/apt/sources.list.d/docker.list
    repo="deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu "
    repo+="$(lsb_release -cs) stable"

    if [ -f "$file" ]; then
        echo "Repository entry already exists."
    else
        echo $repo | sudo tee $file > /dev/null
    fi
    
    sudo apt update
    sudo groupadd docker
    sudo usermod -a -G docker $USER

    [[ "$debug" == "Y" ]] && echo "*** Exiting function: ${FUNCNAME[0]}"
}

function setup_registry
{
    echo Setting up Local Registry.

    file=/etc/docker/share-credentials
    if [ ! -f "$file" ]; then
        echo
        echo Enter credentials for registry share.
        read -p Username: user
        read -s -p Password: pwd

        touch $file
        chmod 600 $file
            
        echo "username=$user" >> $file
        echo "password=$pwd" >> $file

    fi

    mnt=/mnt/docker-registry
    cred=/etc/docker/share-credentials
    entry="//192.168.1.201/docker	$mnt	cifs	credentials=$cred	0	0 "

    if ! grep -q "Docker-Registry" "/etc/fstab"
    then
        mkdir $mnt
        echo "#Docker-Registry" >> /etc/fstab
        echo "$entry" >> /etc/fstab
    else
        echo "Entry in fstab exists."
    fi
    mount -a

    docker run -p 5000:5000 --restart=always --name registry -v $mnt/docker-registry:/var/lib/registry --detach registry serve /var/lib/registry/config.yml

    file=/etc/docker/daemon.json
    if [ ! -f "$file" ]; then
        printf '{\n  "registry-mirrors": ["http://localhost:5000"]\n}\n' > /etc/docker/daemon.json
    fi

    service docker restart

}