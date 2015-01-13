class git_server::server($home="/var/lib/git")
    {
    # Note that you will need to add ssh keys for each developer in users.pp.
    # If you prefer not to touch the code in this module, probably you could also override
    #git_server::users .
    
    # The repository name is also set in bootstrap.bash, so I'm not exposing it for change.
    $repository = "$home/server.git"
        
    user
        {
        "git":
        home => "$home", 
        shell => "/usr/bin/git-shell", 
        system => true,
        } ->

    file
        {
        "$home":
        ensure => directory, 
        owner => "git", 
        group => "git", 
        mode => 0700, 
        } ->

    file
        {
        "$home/.ssh":
        ensure => directory, 
        owner => "git", 
        group => "git", 
        mode => 0700, 
        } ->
        
    file
        {"$repository":
        ensure => directory, 
        owner => "git", 
        group => "git",  
        mode => 0755, 
        } ->
        
    exec
        {
        "git_init":
        command => "/usr/bin/git init --bare .",
        cwd => "$repository",
        onlyif  => "/usr/bin/test -z \"$(ls -A $repository)\"",
        require => Package['git'],
        user => "git",
        }
    }
