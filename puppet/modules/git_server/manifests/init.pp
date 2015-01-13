class git_server()
    {
    Class['git'] -> class{'git_server::server':} -> class{'git_server::users':}
    }
