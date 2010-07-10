For complete documentation refer to [Ray's GitHub page][docs]

---

Usage
---

    # install an extension
    rake ray:extension:install name=extension_name
    
    # search for an extension
    rake ray:extension:search term=search
    
    # disable an extension
    rake ray:extension:disable name=extension_name
    
    # enable an extension
    rake ray:extension:enable name=extension_name
    
    # uninstall an extension
    rake ray:extension:uninstall name=extension_name
    
    # setup server auto-restart for a mongrel_cluster
    rake ray:setup:restart server=mongrel_cluster
    
    # setup server auto-restart for passenger
    rake ray:setup:restart server=passenger
    
    # update your download preference
    rake ray:setup:download
    
    # setup a remote tracking branch
    rake ray:extension:remote name=extension_name remote=other_user
    
    # update an extension's remote branches
    rake ray:extension:pull name=extension_name
    
    # update all extension's remote branches
    rake ray:extension:pull
    
    # view all available extensions
    rake ray:extension:all
    
    # update ray (requires git)
    rake ray:extension:update
    
    # update a single extension
    rake ray:extension:update name=extension_name
    
    # update all extensions
    rake ray:extension:update name=all
    
    # show common command shortcuts
    rake ray:help:shortcuts

Bugs & feature requests
---

Bug reports and feature requests can be created on [Ray's Issue page][bugs]. When filing bugs please include your Radiant and Ray versions, and if appropriate the GitHub URL of the extension you're having trouble with.

[bugs]: http://github.com/johnmuhl/radiant-ray-extension/issues
[docs]: http://johnmuhl.github.com/radiant-ray-extension/