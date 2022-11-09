#!/bin/bash


FILTERED_USERS=("admin")
USER_GROUP="group"
LOCAL_MACHINES=("alias1" "alias2" "user@0.0.0.0")
CONFIG_TEMPLATE="config_template"
BROKEN_KEYS="broken_keys.log"

NEW_ACCOUNTS="accounts/new"
CREATED_ACCOUNTS="accounts/created"
TEST_FILES="accounts/test"
CACHE="accounts/cache"



__usage="
Usage: $(basename $0) command

commands:
  create              create new user accounts
  clean               remove all user accounts created with this script
  test                test the functionality of the script (for debugging)
"


function validate_keys {
  # converts ssh keys to openSSH

  for public_key in ${NEW_ACCOUNTS}/*
  do
    # fix line endings
    sed 's/\r$//' $public_key
    # try to convert the key to openSSH
    ssh_key=$(ssh-keygen -i -f $public_key)
    if [ $? -eq 0 ]
    then
      # if changing the format worked, use the key
      echo $ssh_key > $public_key
    else
      # log the malformed keys
      echo "${public_key}" >> ${BROKEN_KEYS}
    fi
  done
}


function generate_ssh_keys {
  # generates ssh configuration for the user

  mkdir -p $CACHE # temporary cache for user files
  local username=$1
  local ssh_directory=$2
  local public_key="${NEW_ACCOUNTS}/${username}.pub" # external public key
  
  local authorized_keys="${CACHE}/authorized_keys"
  # generate private and public keys for the local network
  ssh-keygen -C $username -f "${CACHE}/id_rsa" -N ''
  # add the external key to authorized keys
  cp $public_key $authorized_keys
  # generate config file for the user based on a template
  sed "s/%USER%/${username}/g" ${CONFIG_TEMPLATE} > "${CACHE}/config"
  # make sure the file permissions are correct

  sudo mkdir -p $ssh_directory
  sudo cp ${CACHE}/* $ssh_directory
  set_file_permissions $username $ssh_directory
}


function set_file_permissions {
  # sets correct file permissions for the ssh configuration

  local username=$1
  local ssh_directory=$2
  sudo chown -R "${username}:${USER_GROUP}" "${ssh_directory}"
  sudo chmod 600 "${ssh_directory}/id_rsa"
  sudo chmod 644 "${ssh_directory}/id_rsa.pub"
}


function bootstrap {
  # bootstraps all the accounts on all servers in the network

  # make sure user group exists
  sudo groupadd ${USER_GROUP}
  if [ "$(ls -A $NEW_ACCOUNTS)" ] #check if there are new users
  then
    # make sure needed folders exist
    mkdir -p $CREATED_ACCOUNTS

    # loop through all the new users
    for user in ${NEW_ACCOUNTS}/*
    do
      #username is the filename without extension
      local username="$(basename -s .pub $user)"
      local ssh_directory="/home/${username}/.ssh"

      # create the user on local machine
      sudo useradd -G ${USER_GROUP} $username
      # generate the contents of .ssh folder
      generate_ssh_keys $username $ssh_directory

      # loop through the servers on local network
      for server in "${LOCAL_MACHINES[@]}"
      do
        # create the user on remote server
        ssh -t $server "sudo useradd -G ${USER_GROUP} ${username}; sudo mkdir ${ssh_directory}; mkdir -p ${CACHE};"
        # copy the ssh configuration to remote server
        scp -r $CACHE/* $server:$CACHE
        # move the ssh configuration to user's .ssh folder
        ssh -t $server "sudo cp ${CACHE}/* /home/${username}/.ssh/; rm -rf ${CACHE};"
        ssh -t $server "$(typeset -f); set_file_permissions $username $ssh_directory"
      done
      # clean the cache afterwards
      rm -rf $CACHE
      # store the created user for future reference (clean up)
      mv "${user}" $CREATED_ACCOUNTS

    done
  fi
}


function clean_users {
  # removes all users created using this script except the ones on the filter list

  # loop through all the users
  for user in ${CREATED_ACCOUNTS}/*
  do
    username="$(basename -s .pub $user)"
    # check that the account is not the admin
    if [[ ! " ${FILTERED_USERS[*]} " =~ " ${username} " ]]
    then
      # kill all the processes of the user
      sudo pkill -KILL -u $username
      # remove the user
      sudo userdel -r $username
      # remove the user from the local network
      for server in "${LOCAL_MACHINES[@]}"
      do
        ssh -t $server "sudo pkill -KILL -u $username; sudo userdel -r $username;"
      done
    fi
  done
}


function purge_users {
  # removes all users except the ones on the filter list

  # loop through all the users
  for user in /home/*
  do
    username="$(basename -s .pub $user)"
    # check that the account is not the admin
    if [[ ! " ${FILTERED_USERS[*]} " =~ " ${username} " ]]
    then
      # kill all the processes of the user
      sudo pkill -KILL -u $username
      # remove the user
      sudo userdel -r $username
      # remove the user from the local network
      for server in "${LOCAL_MACHINES[@]}"
      do
        ssh -t $server "sudo pkill -KILL -u $username; sudo userdel -r $username;"
      done
    fi
  done
}


function test {

  cp ${TEST_FILES}/* $NEW_ACCOUNTS
  mkdir test_tmp
  mv ${CREATED_ACCOUNTS}/* test_tmp
  validate_keys
  bootstrap
  #clean_users
  mv test_tmp/* ${CREATED_ACCOUNTS}
  rm -rf test_tmp
}


if [ $1 ]
then
  case $1 in
    'create')
      validate_keys
      bootstrap
    ;;
    'clean')
      clean_users
    ;;
    'purge')
      purge_users
    ;;
    'test')
      test
    ;;
  *)
  esac
else
  echo "$__usage"
fi

