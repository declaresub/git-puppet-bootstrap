#! /bin/bash

# --ssh-port: SSH port on remote machine.  When configuring a VirtualBox, the port is 
#     usually 2222.  Default value is 22.
# $1 fqdn of server. 
# $2: IP address of server.


# initialize variables with named argument defaults.
PORT=22

# parse named arguments
while true; do
    case "$1" in 
        --ssh-port)
            shift
            PORT="$1"
            shift
            ;;
        *)
        break
    esac
        
done

# what's left should be the positional arguments.

FQDN=$1
HOSTNAME=$(echo $FQDN | cut -d "." -f 1)
REMOTE_ADDR=$2

echo "The server $FQDN will be configured with hostname $HOSTNAME and IP address $REMOTE_ADDR."
echo "Do you wish to proceed?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done



#get the path to the local repository containing this script.  I assume that this script 
#lives in the top level of the repository.
pushd $(dirname $0) > /dev/null
LOCAL_REPO_DIR=$(pwd)
popd > /dev/null

#settings for remote repository setup.
GIT_USER="git"
GIT_HOME="/var/lib/$GIT_USER"
# If you change the value of REPO_NAME, make sure that you also change the value of 
# $git_server::repository and REPO_NAME in run_puppet.bash.
REPO_NAME="server.git"
GIT_REMOTE_NAME=$FQDN
BRANCH=$(cd "$LOCAL_REPO_DIR" && git symbolic-ref --short --quiet HEAD)

echo "Copying puppet configuration to $REMOTE_ADDR."
if ! scp -P "$PORT" -r $LOCAL_REPO_DIR/puppet root@$REMOTE_ADDR: ; then
    echo "Copy failed." >&2
    exit 1
fi


echo "Performing initial setup."
ssh -p "$PORT" -T root@$REMOTE_ADDR <<EOF
#! /bin/bash

echo "Setting hostname."
echo $HOSTNAME> /etc/hostname
hostname -F //etc/hostname

#needed for debian.
echo "Installing lsb-release."
DEBIAN_FRONTEND=noninteractive apt-get install --yes lsb-release

echo "Configuring puppet apt repository."
PUPPET_REPO_DEB="puppetlabs-release-\$(lsb_release --codename --short).deb"
if ! wget http://apt.puppetlabs.com/\$PUPPET_REPO_DEB; then
    exit 1
fi

dpkg -i \$PUPPET_REPO_DEB
rm \$PUPPET_REPO_DEB
apt-get update

echo "Installing puppet."
DEBIAN_FRONTEND=noninteractive apt-get install --yes puppet

if [[ -d /etc/puppet && ! -L /etc/puppet ]]; then
    echo "Moving default puppet configuration /etc/puppet to /etc/puppet.default."
    mv /etc/puppet /etc/puppet.default
fi

echo "Running puppet."

puppet apply --confdir /root/puppet /root/puppet/manifests/init.pp

# At this point, the git repository should have been installed.  We need to set the active
# branch.

if ! cd $GIT_HOME/$REPO_NAME; then
    exit 1
fi
echo "Setting active repository branch to $BRANCH."
if ! git symbolic-ref HEAD refs/heads/$BRANCH; then
    exit 1
fi

echo "Removing bootstrap copy of puppet configuration."
rm -r /root/puppet

EOF

if [[ $? -ne 0 ]]; then
    echo "Initial setup failed."
    exit 1
fi
echo "Initial setup is complete."

cd $LOCAL_REPO_DIR

if ! git remote | grep --quiet  "^${GIT_REMOTE_NAME}\$"; then
    echo "Adding remote to local git repository."
    git remote add $GIT_REMOTE_NAME ssh://$GIT_USER@$REMOTE_ADDR:$PORT$GIT_HOME/$REPO_NAME
fi

echo "Pushing local branch $BRANCH to remote repository $GIT_REMOTE_NAME."
git push --set-upstream $GIT_REMOTE_NAME $BRANCH

#At this point, we should now be able to run puppet on the server.  Let's see how that goes.
echo "Copying run_puppet script to server."
scp -P "$PORT" "run_puppet.bash" root@$REMOTE_ADDR:/usr/local/bin/run_puppet.bash
echo "Running puppet on server."
ssh -p "$PORT" root@$REMOTE_ADDR "/usr/local/bin/run_puppet.bash"
