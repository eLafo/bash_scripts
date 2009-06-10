#!/bin/bash

#This script tries to create a git repository from a subversion one.

#The problem I wanted to solve was to publish some projects into github, which were located in a subversion repository.
#Before publish them, I needed to copy the license terms file in those directories which the license applied to. In fact, these were everyone, except one
#After copying this file, I had to commit the changes to the subversion repository, and then, publish the projects to github

#Ask for the subversion URL
while read -p 'Enter the URL of the repository (svn) '; do
  if [[ ! -z "${REPLY}" ]]; then
    URL=$REPLY
    break
  fi
done

#Ask for the working directory
while read -p 'Enter working directory (svn): '; do
  if [[ ! -z "${REPLY}" ]]; then
    SVN_REPO=$REPLY
    break
  fi
done

#Ask for the username
while read -p 'Enter username (svn): '; do
  if [[ ! -z "${REPLY}" ]]; then
    USERNAME_SVN=$REPLY
    break
  fi
done

#Ask for the password
#TODO: Password should be hidden while typing it

while read -p 'Enter password (svn): '; do
  if [[ ! -z "${REPLY}" ]]; then
    PASSWORD=$REPLY
    break
  fi
done

pwd=$(pwd)
if [ -d $SVN_REPO ]; then
  echo "Using existing directory $SVN_REPO"
else
  echo "Creating not existing directory $SVN_REPO"
  mkdir $SVN_REPO
  echo "Directory $SVN_REPO created"
fi

if [ -d $SVN_REPO/.svn ]; then
  echo "$SVN_REPO is already under control version"
  echo "Updating..."
  cd $SVN_REPO
  svn update
  cd $pwd
else
  echo "Making checkout with $URL"
  svn checkout $URL --username $USERNAME_SVN --password $PASSWORD $SVN_REPO
fi

read -p 'Enter path to the file to be copied in the directory tree (leave blank for none): '
if [ -n "$REPLY" ]; then
#TODO: I am not sure there will not be problems if the file path is entered relative or with ~/
  file=$REPLY
  read -p 'Enter directory path you do not want the file be copied in (leave blank for none): '
    if [ -n "$REPLY" ]; then
      exception=$REPLY
#TODO: It should be able to select more than one directory not to copy the file into
#TODO: The reply should be validated to be an existing directory
      for dir in $(find $SVN_REPO -type d|grep -v $exception); do
        echo "Copying $file to $dir"
        cp $file $dir
      done
    else
      for dir in $(find $SVN_REPO -type d); do
        echo "Copying $file to $dir"
        cp $file $dir
      done
    fi
  TIMESTAMP=`date -u "+%Y%m%dT%H%M%SZ"`
  cd $SVN_REPO
  svn status > /tmp/status_$TIMESTAMP
  grep -e ^A /tmp/status_$TIMESTAMP | sed -e 's/^A//' > /tmp/svn_add_$TIMESTAMP
  rm /tmp/status_$TIMESTAMP

  if [ -s /tmp/svn_add_$TIMESTAMP ]; then
    echo 'Adding files to repo'
    svn add < /tmp/svn_add_$TIMESTAMP
  else
    echo 'There are no files to add'
  fi

  rm /tmp/svn_add_$TIMESTAMP

  svn status > /tmp/status_$TIMESTAMP
  grep -e ^M /tmp/status_$TIMESTAMP | sed -e 's/^M//' > /tmp/svn_commit_$TIMESTAMP

  if [ ! -s /tmp/svn_commit_$TIMESTAMP ]; then
    echo 'There are no changes to commit'
  else
    while read -p 'Enter message for commit (in svn): '; do
      if [[ ! -z "${REPLY}" ]]; then
        COMMIT=$REPLY
        break
      fi
    done
    echo "Commiting files to repo with the message '$COMMIT'"
    svn commit -m "$COMMIT" < /tmp/svn_commit_$TIMESTAMP
  fi
fi

while read -p 'Enter your username in the git repo: '; do
  if [[ ! -z "${REPLY}" ]]; then
    USERNAME=$REPLY
    break
  fi
done

while read -p 'Enter the name of the git repo: '; do
  if [[ ! -z "${REPLY}" ]]; then
    REPO_NAME=$REPLY
    break
  fi
done

cd $pwd

echo "Exporting from svn"
svn export $SVN_REPO $REPO_NAME
  

cd $REPO_NAME
if [ -d .git ]; then
  echo 'Directory under git control. Skipping repo initialize'
else
  git init
fi
while read -p 'Enter message for commit (in git): '; do
if [[ ! -z "${REPLY}" ]]; then
    COMMIT=$REPLY
    break
  fi
done
echo "Commiting files to repo with the message '$COMMIT'"
git add *
git commit -m "$COMMIT"
git remote add origin git@github.com:$USERNAME/$REPO_NAME.git
git push origin master
