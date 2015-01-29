# Git-Puppet Bootstrap

Git-Puppet Bootstrap is a template git repository that sets up a server to be managed with 
a Puppet configuration stored in the repository.  


## Bootstrappery

To create a new server repository, clone this one.  Remove the .git subdirectory, then
run git init.


    mkdir /path/to/new_server
    cd /path/to/new_server
    git clone https://github.com/declaresub/git-puppet-bootstrap.git .
    rm -rf .git
    git init .
    git add *
    git commit -m "Initial commit from git-puppet-bootstrap."
    

Next you must add at least one ssh public key for access to the git repository on the 
server.  It should be placed in the file puppet/environments/production/modules/git_server/manifests/users.pp.

Before:

    class git_server::users()
        {
        #Add ssh_authorized_keys for each person allowed to push changes to the server.
        #Make sure you add yours before running bootstrap.bash.

        }

After:

    class git_server::users()
        {
        #Add ssh_authorized_keys for each person allowed to push changes to the server.
        #Make sure you add yours before running bootstrap.bash.

        ssh_authorized_key
            {
            'git-server':
            ensure => present, 
            user =>"git",
            key => 'PUBLIC_KEY_GOES_HERE',
            type => 'ssh-rsa',
            }
        }
    

You might also add an ssh_authorized_key resource for user 'root' in the main manifest file.  
This will save some typing during the bootstrap process.  And if, like me, you disable SSH 
password authentication, this will save you from locking yourself out of your server while 
tinkering with Puppet.

To run bootstrap.bash, you need the IP address of the target server and the fully-qualified 
domain name.  The script also takes an optional argument --ssh-port that sets the port for ssh 
connections to the server.  This is useful when setting up a development box with Vagrant.

    ./bootstrap.bash --ssh-port 22 test.example.com 192.168.1.1
    
You will need to enter a password for root a few times.


## What Does bootstrap.bash Do?
 
In short, bootstrap.bash creates a clone of this git repository on the server and runs 
Puppet with the configuration in the repository.  

In particular, bootstrap.bash does the following:

* Copies your local repository to the server; note that it will set the current branch of that 
repository to the current branch of the local repository
* Sets the hostname of the server to the fully-qualified domain name you passed to the script
* Adds the puppetlabs apt repository and installs Puppet
* Runs Puppet using the configuration in the git repository
* Sets the current branch of that repository to the same value as your local repository
* Adds a remote to your local git repository
* Pushes from the local git repository to the server; note that if your forgot to add your 
ssh public key as directed above, this step will fail
* Installs run_puppet.bash in /usr/local/bin
* Runs puppet once again.

The action of bootstrap.bash is intended to be idempotent and mostly crash-proof.  Thus if 
something goes awry, you should be able to kill the script and run it repeatedly. Problems 
you may encounter include

* Forgetting to provide your ssh public key to user git
* Network issues with apt-get


## What Does run_puppet.bash Do?

The script run_puppet.bash handles extraction of the Puppet configuration from the git 
repository and the execution of the command puppet apply.  In particular, it

* Checks to see if a new commit has been pushed since run_puppet.bash was last executed
* Gets Puppet configuration from git repository and writes it to a directory like 
/etc/puppet.944c53f, where 944c53f is the prefix of the commit hash
* Sets a symlink at /etc/puppet to /etc/puppet.944c53f
* Updates /usr/local/bin/run_puppet.bash
* Executes puppet apply.

You can execute this script yourself.  It has two options --quiet and --debug.  

* --quiet: suppresses anything written to stdout
* --debug: enables the --debug option of puppet apply.



