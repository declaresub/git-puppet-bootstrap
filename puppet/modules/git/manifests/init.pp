# Feel free to replace this module with a git module that better suits your needs.
# git_server module requires git.

class git()
    {
    package{'git': ensure => installed}
    }
