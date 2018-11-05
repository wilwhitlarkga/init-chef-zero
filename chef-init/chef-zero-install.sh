#!/bin/bash

###### Chef-init
###### Intended to be housed on an AMI
###### and triggered on AMI launch.
###### Pulls the latest chef code,
###### installs chef-zero,
###### and uses AWS tags to determine
###### nodetype.  Other AWS tags are
###### stored with the intention of
###### retrieving their values within
###### chef recipes.

# Store external IP for processing
if [[ `cat /opt/extip 2>/dev/null` == "" ]]; then
  ifconfig | grep inet | grep -v inet6 | grep -v 127.0.0.1 | awk '{print $2}' | head -1 | cut -c6- > /opt/extip
fi

# Store AWS tags for processing
## Note: This requires 'aws configure' to run in the AMI and
## IAM credentials provided that permit describe-tags
if [ ! -f /opt/aws_instance_id ]; then
  instance_id=`curl -s $DOC_API | grep -oP 'instanceId[^i]+\K..[0-9a-f]+'`
  region=`curl -s $DOC_API | grep region | awk -F\" '{print $4}'`
  echo $instance_id > /opt/aws_instance_id
  echo $region > /opt/aws_instance_region
  for rkey in Name env nodetype; do
    aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=$rkey" --region=$region --output=text | cut -f5 > /opt/aws_tags_$rkey
  done
fi

# Statics and stored values
INSTALL_DIR='/opt/repo'
DOC_API='http://169.254.169.254/latest/dynamic/instance-identity/document'
MAX_CHEF_RUN_FAILURES=3
node_type=`cat /opt/aws_tags_nodetype`

# Check for an existing nodetype.  If not found, do not proceed.
if [[ x$node_type == 'x' ]]; then
  exit 1
fi

## Pull connection key if not present
## Note: This needs to come from within the VPC
#if [[ `cat ~/.ssh/id_rsa` == "" ]]; then
#  mkdir -p ~/.ssh
#  curl http://172.31.IP.IP/SERVER-CONNECT-KEY > ~/.ssh/id_rsa
#  chmod 0600 ~/.ssh/id_rsa
#fi

## Install git if not present
yum install -y git

## Install chef if not present
if [[ `rpm -qa | grep -m1 -o chef` != "chef" ]]; then
  curl -L https://omnitruck.chef.io/install.sh | bash
fi

# Enter install dir to deliver repo clone
mkdir -p $INSTALL_DIR
pushd $INSTALL_DIR

### either
## Initialize ssh connection to git host on port XXXX
#ssh -o StrictHostKeyChecking=no OUGITREPO.LOCATION.TLD -p XXXX ls >/dev/null 2>&1
#if [ ! -d /opt/repo/init-chef ]; then
#  git clone ssh://git@OUGITREPO.LOCATION.TLD:XXXX/init-chef.git
#fi

### or
## Pull latest from Github git host
if [ ! -d $INSTALL_DIR/init-chef ]; then
  git clone https://github.com/generalassembly/init-chef.git
fi

popd

# Enter cloned dir to start operation 
pushd $INSTALL_DIR/init-chef

# Grab chef-zero init json for node type
mkdir -p $INSTALL_DIR/init-chef/data_bags/applications/
/bin/cp -f $INSTALL_DIR/init-chef/chef-init/${node_type}.json /opt/repo/init-chef/data_bags/applications/install.json

# Deliver current hostname to node directory
/bin/cp -f $INSTALL_DIR/init-chef/nodes/node_install.json $INSTALL_DIR/init-chef/nodes/`hostname`.json

# Iterate installs until success or we fail out
z='0'
i='1'
while [[ $z != $MAX_CHEF_RUN_FAILURES ]]; do
  chef-client -z -E `cat /opt/aws_tags_env`
  i=`echo $?`
  if [[ `echo $i` != '0' ]]; then
    z=$(( z + 1 ))
  else
    z='9'
  fi
done

popd
