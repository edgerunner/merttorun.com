namespace :ray do

  require "fileutils"
  require "open-uri"
  require "yaml"

  @p = "vendor/extensions"
  @r = "#{@p}/ray"
  @c = "#{@r}/config"

  namespace :extension do
    desc "Install an extension."
    task :install do
      require_options = [ENV["name"]]
      get_name(require_options)
      install_extension
    end
    desc "Search available extensions."
    task :search do
      messages = [
        "A SEARCH TERM IS REQUIRED! For example:",
        "rake ray:extension:search term=search_term"
      ]
      require_options = [ENV["term"]]
      get_name(require_options, search=true)
      search_extensions(show = true)
    end
    desc "Disable an extension."
    task :disable do
      messages = [
        "AN EXTENSION NAME IS REQUIRED! For example:",
        "rake ray:extension:disable name=extension_name"
      ]
      require_options = [ENV["name"]]
      get_name(require_options)
      disable_extension
    end
    desc "Enable an extension."
    task :enable do
      messages = [
        "AN EXTENSION NAME IS REQUIRED! For example:",
        "rake ray:extension:enable name=extension_name"
      ]
      require_options = [ENV["name"]]
      get_name(require_options)
      enable_extension
    end
    desc "Uninstall an extension"
    task :uninstall do
      messages = [
        "AN EXTENSION NAME IS REQUIRED! For example:",
        "rake ray:extension:uninstall name=extension_name"
      ]
      require_options = [ENV["name"]]
      get_name(require_options)
      uninstall_extension
    end
    desc "Update existing remotes on an extension."
    task :pull do
      require_git
      pull_remote
    end
    desc "Setup a new remote on an extension."
    task :remote do
      require_git
      messages = [
        "AN EXTENSION NAME AND GITHUB USERNAME ARE REQUIRED! For example:",
        "rake ray:extension:remote name=extension_name hub=user_name"
      ]
      require_options = [ENV["name"], ENV["hub"]]
      validate_command(messages, require_options)
      add_remote
    end
    desc "Install an extension bundle."
    task :bundle do
      install_bundle
    end
    desc "View all available extensions."
    task :all do
      search_extensions(show = true)
    end
    desc "Update an extension."
    task :update do
      update_extension
    end
    desc "Go to an extension's page on Github."
    task :home do
      require "#{@r}/lib/launchy"
      unless ENV["name"]
        print("Extension name: ")
        ENV["name"] = STDIN.gets.strip!
      end
      search_extensions(show = false)
      Launchy.open("#{@url}/tree/master")
      exit
    end
  end

  namespace :setup do
    desc "Set server auto-restart preference."
    task :restart do
      messages = [
        "A SERVER TYPE IS REQUIRED! For example:",
        "rake ray:setup:restart server=mongrel_cluster",
        "rake ray:setup:restart server=mongrel",
        "rake ray:setup:restart server=passenger",
        "rake ray:setup:restart server=thin",
        "rake ray:setup:restart server=unicorn",
        "NOTE: Mongrel, Thin and Unicorn must be running as daemons"
      ]
      require_options = [ENV["server"]]
      validate_command(messages, require_options)
      set_restart_preference
    end
    desc "Set extension download preference."
    task :download do
      set_download_preference
    end
  end

  namespace :help do
    desc "Show Ray shortcuts."
    task :shortcuts do
      messages = [
        "rake ray:s term=extension_name # search",
        "rake ray:i name=extension_name # install",
        "rake ray:d name=extension_name # disable",
        "rake ray:e name=extension_name # enable"
      ]
      output(messages)
    end
  end

  # i've gotten progressively lazier
  task :ext => ["extension:install"]
  task :search => ["extension:search"]
  task :dis => ["extension:disable"]
  task :en => ["extension:enable"]
  task :i => ["extension:install"]
  task :s => ["extension:search"]
  task :d => ["extension:disable"]
  task :e => ["extension:enable"]
  task :h => ["extension:home"]

end

def install_extension
  get_download_preference
  search_extensions(show = nil)
  replace_github_username if ENV["hub"]
  replace_extension_name if ENV["fullname"]
  if ENV["lib"]
    @gem_dependencies = [ENV["lib"]]
    install_dependencies
  end
  determine_install_path # cancels installation if extension exists
  check_submodules
  check_dependencies
  run_extension_tasks
  messages = [
    "The #{@name} extension has been installed successfully."
  ]
  output(messages)
  restart_server
end

def disable_extension
  normalize_name
  move_to_disabled
  messages = ["The #{@name} extension has been disabled."]
  output(messages)
  restart_server
end

def enable_extension
  normalize_name
  if File.exist?("#{@p}/#{@name}")
    remove_dir("#{@p}/.disabled/#{@name}")
    messages = [
      "The #{@name} extension was re-installed after it was disabled.",
      "So there is no reason to re-enable the version you previously disabled.",
      "I removed the duplicate, disabled copy of the extension."
    ]
    output(messages)
    exit
  end
  if File.exist?("#{@p}/.disabled/#{@name}")
    FileUtils.mv("#{@p}/.disabled/#{@name}", "#{@p}/#{@name}")
    messages = ["The #{@name} extension has been enabled."]
    output(messages)
  else
    messages = [
      "The #{@name} extension is not disabled.",
      "If you were trying to install the extension try running:",
      "rake ray:extension:install name=#{@name}"
    ]
    output(messages)
    exit
  end
  restart_server
end

def update_extension
  name = ENV["name"] if ENV["name"]
  # update all extensions, except ray
  if name == "all"
    get_download_preference
    extensions = Dir.entries(@p) - [".", "..", ".DS_Store", ".disabled", "ray"]
    if @download == "git"
      extensions.each do |name|
        git_extension_update(name)
      end
    elsif @download == "http"
      extensions.each do |name|
        http_extension_update(name)
      end
    else
      messages = [
        "Your download preference is broken, to repair it run:",
        "rake ray:setup:download"
      ]
      output(messages)
      exit
    end
  # update a single extension
  elsif name
    get_download_preference
    if @download == "git"
      git_extension_update(name)
    elsif @download == "http"
      http_extension_update(name)
    else
      messages = [
        "Your download preference is broken, to repair it run:",
        "rake ray:setup:download"
      ]
      output(messages)
      exit
    end
  # update ray
  else
    name = "ray"
    get_download_preference
    if @download == "git"
      git_extension_update(name)
    elsif @download == "http"
      messages = [
        "Ray can only update itself with git."
      ]
      output(messages)
      exit
    else
      messages = [
        "Your download preference is broken, to repair it run:",
        "rake ray:setup:download"
      ]
      output(messages)
      exit
    end
  end
end

def install_bundle
  unless File.exist?("config/extensions.yml")
    messages = [
      "You don't seem to have a bundle file available.",
      "Refer to the documentation for more information on extension bundles.",
      "http://johnmuhl.github.com/radiant-ray-extension/#ext-bundle"
    ]
    output(messages)
    exit
  end
  File.open("config/extensions.yml") do |bundle|
    # load up a yaml file and send the contents back into ray for installation
    YAML.load_documents(bundle) do |extension|
      for i in 0...extension.length do
        name = extension[i]["name"]
        options = []
        options << " hub=" + extension[i]["hub"] if extension[i]["hub"]
        options << " lib=" + extension[i]["lib"] if extension[i]["lib"]
        options << " fullname=" + extension[i]["fullname"] if extension[i]["fullname"]
        sh("rake -q ray:extension:install name=#{name}#{options}")
        remote = extension[i]["remote"] if extension[i]["remote"]
        if remote
          unless remote.class.to_s == "Array"
            messages = [
              "Your extensions.yml file is using Ray 1.x features no longer in Ray 2.",
              "Refer to the wiki for upgrade information, http://is.gd/jV5h"
            ]
            output(messages)
            exit
          end
          remote.each { |a| sh("rake -q ray:extension:remote name=#{name} hub=#{a}") }
          sh("rake -q ray:extension:pull name=#{name}")
        end
      end
    end
  end
end

def git_extension_install
  @url.gsub!(/http/, "git")
  # check if the user is cloning their own repo and switch to ssh
  # use public=true to force the public url to be used on your own repos
  unless ENV["public"]
    home = `echo ~`.gsub!("\n", "")
    if File.exist?("#{home}/.gitconfig")
      File.readlines("#{home}/.gitconfig").map do |f|
        line = f.rstrip
        if line.include?("user = ")
          me = line.gsub(/\tuser\ =\ /, "")
          origin = @url.gsub(/git:\/\/github.com\/(.*)\/.*/, "\\1")
          @url.gsub!(/git:\/\/github.com\/(.*\/.*)/, "git@github.com:\\1") if me == origin
        end
      end
    end
  end
  if File.exist?(".git/HEAD")
    sh("git submodule -q add #{@url}.git #{@p}/#{@name}")
  else
    sh("git clone -q #{@url}.git #{@r}/tmp/#{@name}")
  end
end

def http_extension_install
  FileUtils.makedirs("#{@r}/tmp")
  begin
    tarball = open("#{@url}/tarball/master", "User-Agent" => "open-uri").read
  rescue Exception
    messages = [
      "GitHub failed to serve the requested extension archive.",
      "These are usually temporary issues, just try it again."
    ]
    output(messages)
    exit
  end
  open("#{@r}/tmp/#{@name}.tar.gz", "wb") { |f| f.write(tarball) }
  Dir.chdir("#{@r}/tmp") do
    begin
      sh("tar xzvf #{@name}.tar.gz")
    rescue Exception
      rm("#{@name}.tar.gz")
      messages = [
        "The #{@name} extension archive is not decompressing properly.",
        "You can usually fix this by simply running the command again."
      ]
      output(messages)
      exit
    end
    rm("#{@name}.tar.gz")
  end
  @name = Dir.entries("#{@r}/tmp") - ['.', '..', '.DS_Store']
  @http = true
end

def git_extension_update(name)
  Dir.chdir("#{@p}/#{name}") do
    sh("git checkout -q master")
    sh("git pull -q origin master")
    messages = ["The #{name} extension has been updated."]
    output(messages)
  end
end

def http_extension_update(name)
  puts("================================================================================")
  Dir.chdir("#{@p}/#{name}") do
    sh("rake -q ray:extension:disable name=#{name}")
    sh("rake -q ray:extension:install name=#{name}")
    remove_dir("#{@r}/disabled_extensions/#{name}")
    messages = ["The #{name} extension has been updated."]
    output(messages)
  end
end

def check_dependencies
  d = Dir.entries("#{@p}/#{@name}").detect { |f| f.match /^dependenc/ }
  if d
    @extension_dependencies = []
    @gem_dependencies       = []
    @plugin_dependencies    = []
    File.open("#{@p}/#{@name}/#{d}") do |f|
      YAML.load_documents(f) do |d|
        for i in 0...d.length
          if d[i]["extension"]
            dependency = {}
            dependency["name"] = d[i]["extension"]
            dependency["hub"] = d[i]["hub"] if d[i]["hub"]
            dependency["radiant_min_version"] = d[i]["radiant_min_version"] if d[i]["radiant_min_version"]
            dependency["radiant_max_version"] = d[i]["radiant_max_version"] if d[i]["radiant_max_version"]
            install_extension_dependencies(dependency)
          else
            @gem_dependencies << d[i]["gem"] if d[i].include?("gem")
            @plugin_dependencies << d[i]["plugin"] if d[i].include?("plugin")
            install_dependencies
          end
        end
      end
    end
  end
end

def install_extension_dependencies(dependency)
  if dependency["radiant_min_version"] or dependency["radiant_max_version"]
    version = Radiant::Version.to_s
    if dependency["radiant_min_version"] and dependency["radiant_max_version"]
      min = dependency["radiant_min_version"]
      max = dependency["radiant_max_version"]
      min_max_sanity_check(min, max)
      if min < version and max > version
        if dependency["hub"]
          system("rake -q ray:extension:install name=#{dependency["name"]} hub=#{dependency["hub"]}")
        else
          ENV["hub"] = nil
          system("rake -q ray:extension:install name=#{dependency["name"]}")
        end
      elsif min > version
        system("rake -q ray:extension:disable name=#{@name}")
        messages = [
                    "You need at least Radiant #{min} to use the #{@name} extension."
                   ]
        output(messages)
        exit
      elsif max < version
        messages = [
                    "The #{dependency['name']} extension is no longer needed and was not installed."
                   ]
        output(messages)
      end
    elsif dependency["radiant_min_version"] and dependency["radiant_max_version"] == nil
      min = dependency["radiant_min_version"]
      if min > version
        system("rake -q ray:extension:disable name=#{@name}")
        messages = [
                    "You need at least Radiant #{min} to use the #{@name} extension."
                   ]
        output(messages)
        exit
      else
        if dependency["hub"]
          system("rake -q ray:extension:install name=#{dependency["name"]} hub=#{dependency["hub"]}")
        else
          ENV["hub"] = nil
          system("rake -q ray:extension:install name=#{dependency["name"]}")
        end
      end
    elsif dependency["radiant_max_version"] and dependency["radiant_min_version"] == nil
      max = dependency["radiant_max_version"]
      if max < version
        messages = [
                    "The #{dependency['name']} extension is no longer needed and was not installed."
                   ]
        output(messages)
      else
        if dependency["hub"]
          system("rake -q ray:extension:install name=#{dependency["name"]} hub=#{dependency["hub"]}")
        else
          ENV["hub"] = nil
          system("rake -q ray:extension:install name=#{dependency["name"]}")
        end
      end
    end
  else
    if dependency["hub"]
      system("rake -q ray:extension:install name=#{dependency["name"]} hub=#{dependency["hub"]}")
    else
      ENV["hub"] = nil
      system("rake -q ray:extension:install name=#{dependency["name"]}")
    end
  end
end

def min_max_sanity_check(min, max)
  min = min.gsub("\.", "").to_i + 1
  max = max.gsub("\.", "").to_i
  if min == max
    system("rake -q ray:extension:disable name=#{@name}")
    messages = [
                "The author of the #{@name} extension has inadvertently specified a minimum and",
                "maximum version that make it impossible to install. Please contact the author."
               ]
    output(messages)
    exit
  end
end

def check_submodules
  if File.exist?("#{@p}/#{@name}/.gitmodules")
    submodule_urls = []
    submodule_paths = []
    File.readlines("#{@p}/#{@name}/.gitmodules").map do |f|
      line = f.rstrip
      submodule_urls << line.gsub(/\turl\ =\ /, "") if line.include? "url = "
      submodule_paths << line.gsub(/\tpath\ =\ /, "") if line.include? "path = "
    end
    install_submodules(submodule_urls, submodule_paths)
  end
end

def install_dependencies
  if @extension_dependencies
    @extension_dependencies.each { |e| system "rake -q ray:extension:install name=#{e}" }
  end
  if @gem_dependencies
    gem_sources = `gem sources`.split("\n")
    gem_sources.each { |g| @github = g if g.include?("github") }
    sh("gem sources --add http://gems.github.com") unless @github
    @gem_dependencies.each do |g|
      has_gem = `gem list #{g}`.strip
      if has_gem.length == 0
        messages = [
          "The #{@name} extension requires one or more gems.",
          "YOU MAY BE PROMPTED FOR YOU SYSTEM ADMINISTRATOR PASSWORD!"
        ]
        output(messages)
        sh("sudo gem install #{g}")
      end
    end
  end
  if @plugin_dependencies
    messages = [
      "Plugin dependencies are not supported by Ray, use git submodules instead.",
      "If you're not the extension author consider contacting them about this issue."
    ]
    output(messages)
    @plugin_dependencies.each do |p|
      messages = [
        "The #{@name} extension requires the #{p} plugin.",
        "Please install the #{p} plugin manually."
      ]
      output(messages)
    end
  end
end

def install_submodules(submodule_urls, submodule_paths)
  if @download == "git"
    submodule_urls.each do |url|
      Dir.chdir("#{@p}/#{@name}") do
        sh("git submodule -q init")
        sh("git submodule -q update")
      end
    end
  elsif @download == "http"
    submodule_urls.each do |url|
      FileUtils.makedirs("#{@r}/tmp")
      url.gsub!(/(git:)(\/\/github.com\/.*\/.*)(.git)/, "http:\\2/tarball/master")
      tarball = open("#{url}", "User-Agent" => "open-uri").read
      url.gsub!(/http:\/\/github.com\/.*\/(.*)\/tarball\/master/, "\\1")
      open("#{@r}/tmp/#{url}.tar.gz", "wb") { |f| f.write(tarball) }
      Dir.chdir("#{@r}/tmp") do
        begin
          sh("tar xzvf #{url}.tar.gz")
        rescue Exception
          rm("#{url}.tar.gz")
          messages = [
            "GitHub failed to serve the requested archive.",
            "These issues are usually temporary, just try again."
          ]
          output(messages)
          exit
        end
        rm("#{url}.tar.gz")
      end
      sh("mv #{@r}/tmp/* #{@p}/#{@name}/#{submodule_paths[submodule_urls.index(url)]}")
      remove_dir("#{@r}/tmp")
    end
  else
    messages = [
      "Your download preference is broken, to repair it run:.",
      "rake -q ray:setup:download"
    ]
    output(messages)
    exit
  end
end

def run_extension_tasks
  if File.exist?("#{@p}/#{@name}/lib/tasks")
    rake_files = Dir.entries("#{@p}/#{@name}/lib/tasks") - [".", ".."]
    if rake_files.length == 1
      rake_file = rake_files[0]
    else
      rake_files.each do |f|
        rake_file = f if f.include?("_extension_tasks.rake")
      end
    end
    tasks = []
    File.readlines("#{@p}/#{@name}/lib/tasks/#{rake_file}").map do |f|
      line = f.rstrip
      tasks << "install" if line.include? "task :install =>"
      tasks << "migrate" if line.include? "task :migrate =>"
      tasks << "update" if line.include? "task :update =>"
    end
    unless tasks.empty?
      if ENV['RAILS_ENV']
        env = ENV['RAILS_ENV']
      else
        env = "development"
      end
      if @uninstall
        uninstall_error_messages = [
          "The #{@name} extension failed to uninstall properly.",
          "You can uninstall the extension manually by running:",
          "rake -q #{env} radiant:extensions:#{@name}:migrate VERSION=0",
          "and then removing any associated files and directories."
        ]
        if tasks.include?("uninstall")
          begin
            sh("rake -q #{env} radiant:extensions:#{@name}:uninstall")
          rescue Exception
            messages = uninstall_error_messages
            output(messages)
            exit
          end
        else
          if tasks.include?("migrate")
            begin
              sh("rake -q #{env} radiant:extensions:#{@name}:migrate VERSION=0")
            rescue Exception
              messages = uninstall_error_messages
              output(messages)
              exit
            end
          end
          # do a simple search to find files to remove, misses are frequent
          if tasks.include?("update")
            require "find"
            files = []
            Find.find("#{@p}/#{@name}/public") { |file| files << file }
            files.each do |f|
              if f.include?(".")
                unless f.include?(".DS_Store")
                  file = f.gsub(/#{@p}\/#{@name}\/public/, "public")
                  FileUtils.rm("#{file}", :force => true)
                end
              end
            end
          end
        end
      else
        if tasks.include?("install")
          begin
            sh("rake -q RAILS_ENV=#{env} radiant:extensions:#{@name}:install")
          rescue Exception => error
            cause = "install"
            quarantine_extension(cause)
          end
        else
          if tasks.include?("migrate")
            begin
              sh("rake -q RAILS_ENV=#{env} radiant:extensions:#{@name}:migrate")
            rescue Exception => error
              cause = "migrate"
              quarantine_extension(cause)
            end
          end
          if tasks.include?("update")
            begin
              sh("rake -q RAILS_ENV=#{env} radiant:extensions:#{@name}:update")
            rescue Exception => error
              cause = "update"
              quarantine_extension(cause)
            end
          end
        end
      end
    end
    puts("The #{@name} extension has no tasks to run.") if tasks.empty?
  else
    puts("The #{@name} extension has no task file.")
  end
end

def uninstall_extension
  @uninstall = true
  normalize_name
  unless File.exist?("#{@p}/#{@name}")
    messages = ["The #{@name} extension is not installed."]
    output(messages)
    exit
  end
  run_extension_tasks
  FileUtils.makedirs("#{@r}/tmp")
  FileUtils.mv("#{@p}/#{@name}", "#{@r}/tmp/#{@name}")
  remove_dir("#{@r}/tmp")
  messages = ["The #{@name} extension has been uninstalled."]
  output(messages)
  restart_server
end

def search_extensions(show)
  check_search_freshness
  name = ENV["name"] if ENV["name"]
  term = ENV["term"] if ENV["term"]
  extensions = []
  authors = []
  urls = []
  descriptions = []
  File.open("#{@r}/search.yml") do |repositories|
    YAML.load_documents(repositories) do |repository|
      for i in 0...repository["repositories"].length
        e = repository["repositories"][i]["name"]
        if name or term
          d = repository["repositories"][i]["description"]
          if name
            term = name
          elsif term
            name = term
          end
          if e.include?(term) or e.include?(name) or d.include?(term) or d.include?(name)
            extensions << e
            authors << repository["repositories"][i]["owner"]
            urls << repository["repositories"][i]["url"]
            descriptions << d
          end
        else
          extensions << e
          authors << repository["repositories"][i]["owner"]
          urls << repository["repositories"][i]["url"]
          descriptions << repository["repositories"][i]["description"]
        end
      end
    end
  end
  if show
    show_search_results(term, extensions, authors, urls, descriptions)
  else
    choose_extension_to_install(name, extensions, authors, urls, descriptions)
  end
end

def show_search_results(term, extensions, authors, urls, descriptions)
  if extensions.length == 0
    messages = ["Your search term '#{term}' did not match any extensions."]
    output(messages)
    exit
  end
  puts "================================================================================"
  for i in 0...extensions.length
    extension = extensions[i].gsub(/radiant-/, "").gsub(/-extension/, "")
    if descriptions[i].length >= 63
      description = descriptions[i][0..63] + "..."
    elsif descriptions[i].length == 0
      description = "(no description provided)"
    else
      description = descriptions[i]
    end
    messages = [
      "  extension: #{extension}",
      "     author: #{authors[i]}",
      "description: #{description}",
      "    command: rake ray:extension:install name=#{extension}",
      "================================================================================"
    ]
    output(messages, short=true)
  end
  exit
end

def choose_extension_to_install(name, extensions, authors, urls, descriptions)
  @name = ENV['name']
  if extensions.length == 1
    @url = urls[0]
    return
  end
  if extensions.include?(name) or extensions.include?("radiant-#{name}-extension")
    extensions.each do |e|
      extension_name = e.gsub(/radiant[-|_]/, "").gsub(/[-|_]extension/, "")
      @url = urls[extensions.index(e)]
      break if extension_name == name
    end
  elsif extensions.length == 0
    @blind_luck = true
    messages = [
      "I couldn't find the '#{name}' extension.",
      "Trying to fetch it directly from GitHub..."
    ]
    output(messages, short=true)
    @url = "http://github.com/radiant/radiant-#{name}-extension"
    return
  else
    messages = [
      "No extensions matched '#{name}'.",
      "The following extensions might be related.",
      "Use the command listed to install an extension."
    ]
    output(messages)
    show_search_results(term = name, extensions, authors, urls, descriptions)
  end
end

def get_download_preference
  unless File.exist?("#{@r}/preferences.yml")
    set_download_preference
  end
  preferences = YAML::load_file("#{@r}/preferences.yml")
  dl = preferences["download"]
  if dl
    @download = dl.strip
  else
    set_download_preference
  end
  unless @download == "git" or @download == "http"
    messages = [
      "Your download preference is broken, to repair it run:",
      "rake ray:setup:download",
    ]
    output(messages)
    exit
  end
end

def set_download_preference
  if File.exist?("#{@c}/download.txt")
    File.open("#{@c}/download.txt", "r") { |f| @download = f.gets.strip! }
    rm("#{@c}/download.txt")
  else
    if `which git`.strip.include?("git")
      @download = "git"
    else
      @download = "http"
    end
  end
  unless File.exist?("#{@r}/preferences.yml")
    File.open("#{@r}/preferences.yml", "w") { |f| f.puts("---\n") }
  end
  File.open("#{@r}/preferences.yml", "a") { |f| f.puts("  download: #{@download}") }
  messages = [
    "Your download preference has been set to #{@download}."
  ]
  output(messages)
end

def set_restart_preference
  supported_servers = ["mongrel_cluster", "mongrel", "passenger", "thin", "unicorn"]
  server = ENV["server"]
  if supported_servers.include?(server)
    if File.exist?("#{@r}/preferences.yml")
      preferences = YAML::load_file("#{@r}/preferences.yml")
      rm("#{@r}/preferences.yml")
      dl = preferences["download"] if preferences["download"]
    end
    File.open("#{@r}/preferences.yml", "w") { |f| f.puts("---\n") }
    File.open("#{@r}/preferences.yml", "a") { |f| f.puts("  download: #{dl}\n  restart: #{server}") }
    messages = ["Your restart preference has been set to #{server}."]
    output(messages)
    exit
  else
    messages = [
      "I don't know how to restart #{server}.",
      "Single Mongrels, Mongrel clusters, Thin, Unicorn and Phusion Passenger are supported.",
      "NOTE: Mongrel, Thin and Unicorn must be running as daemons",
      "Run one of the following commands:",
      "rake ray:setup:restart server=mongrel_cluster",
      "rake ray:setup:restart server=passenger",
      "rake ray:setup:restart server=mongrel",
      "rake ray:setup:restart server=thin",
      "rake ray:setup:restart server=unicorn"
    ]
    output(messages)
    exit
  end
end

def validate_command(messages, require_options)
  require_options.each do |option|
    unless option
      output(messages)
      exit
    end
  end
end

def get_name(require_options, search=nil)
  if search
    unless ENV['term']
      print("Search term: ")
      ENV['term'] = STDIN.gets.strip!
    end
  else
    unless ENV['name']
      print("Extension name: ")
      ENV['name'] = STDIN.gets.strip!
    end
  end
end

def output(messages, short=nil)
  puts "================================================================================" unless short
  messages.each { |m| puts "#{m}" }
  messages = []
  puts "================================================================================" unless short
end

def replace_github_username
  @url.gsub!(/(http:\/\/github.com\/).*(\/.*)/, "\\1#{ENV["hub"]}\\2")
end

def replace_extension_name
  @url.gsub!(/(http:\/\/github.com\/.*\/)(.*)/, "\\1#{ENV["fullname"]}")
end

def determine_install_path
  FileUtils.makedirs("#{@r}/tmp")
  # download repository contents
  git_extension_install if @download == "git"
  http_extension_install if @download == "http"
  @name = directory_name if @download == "http"
  if @blind_luck
    messages = [
      "No extension could be found at: ",
      "#{@url}",
      "Check the URL for a hint about what's going on."
    ]
  else
    messages = ["GitHub is having trouble serving the request, try again."]
  end

  # find vendor/extensions/ray/tmp/ext_name/ext_name_extension.rb
  unless @download == "git" && File.exist?(".git/HEAD")
    extension_files = Dir.entries("#{@r}/tmp/#{@name}") - ['.','..','.DS_Store']
    extension_files.each { |f|
      @name = f.gsub(/(.*)_extension.rb/, "\\1") if f =~ /.*_extension.rb/
    }
    check_for_existing_installation
  end
end

def check_for_existing_installation
  if File.exist?("#{@p}/#{@name}")
    remove_dir("#{@r}/tmp")
    messages = [ "The #{@name} extension is already installed." ]
    output(messages)
    exit
  else
    mv("#{@r}/tmp/#{ENV['name']}", "#{@p}/#{@name}")
    remove_dir("#{@r}/tmp")
    if @http
      if File.exist?("#{@p}/#{@name}/.gitmodules")
        check_submodules
        rm("#{@p}/#{@name}/.gitmodules")
      end
    end
  end
end

def move_to_disabled
  FileUtils.makedirs("#{@p}/.disabled")
  if File.exist?("#{@p}/#{@name}")
    if File.exist?("#{@p}/.disabled/#{@name}")
      remove_dir("#{@p}/.disabled/#{@name}")
    end
    FileUtils.mv("#{@p}/#{@name}", "#{@p}/.disabled/#{@name}")
  else
    messages = [
      "The #{@name} extension is not installed."
    ]
    output(messages)
    exit
  end
end

def quarantine_extension(cause)
  move_to_disabled
  messages = [
              "The #{@name} extension failed to install properly.",
              "Specifically, the failure was caused by the extension's #{cause} task:",
              "The extension has been disabled and placed in #{@p}/.disabled",
              "If you would like to troubleshoot the extension re-enable it by running:",
              "`rake ray:extension:enable name=#{@name}` then run the #{cause} task with:",
              "`rake radiant:extensions:#{@name}:#{cause} --trace` and inspect the output."
             ]
  output(messages)
  exit
end

def require_git
  get_download_preference
  unless @download == "git"
    messages = [
      "THIS COMMANDS REQUIRES GIT!",
      "Refer to http://git-scm.com/ for installation instructions."
    ]
    output(messages)
    exit
  end
end

def restart_server
  if File.exist?("#{@c}/restart.txt")
    File.open("#{@c}/restart.txt", "r") { |f| @server = f.gets.strip! }
    rm("#{@c}/restart.txt")
    unless File.exist?("#{@r}/preferences.yml")
      File.open("#{@r}/preferences.yml", "w") { |f| f.puts("---\n") }
    end
    File.open("#{@r}/preferences.yml", "a") { |f| f.puts("  restart: #{@server}") }
  end
  begin
    preferences = YAML::load_file("#{@r}/preferences.yml")
  rescue
    messages = [
      "Ray can automatically restart common application servers.",
      "Refer to the documentation for more information on auto-restart.",
      "http://johnmuhl.github.com/radiant-ray-extension/#setup-restart"
    ]
    output(messages, short=true)
    exit
  end
  @server = preferences["restart"].strip if preferences["restart"]
  if @server == "passenger"
    FileUtils.makedirs("tmp")
    FileUtils.touch("tmp/restart.txt")
    puts("Passenger restarted.")
  elsif @server == "mongrel_cluster"
    sh("mongrel_rails cluster::restart")
    puts("Mongrel cluster restarted.")
  elsif @server == "mongrel"
    sh("mongrel_rails restart")
    puts("Mongrel has been restarted")
  elsif @server == "thin"
    sh("thin restart")
    puts("Thin has been restarted")
  elsif @server == "unicorn"
    if File.exist?("tmp/pids/unicorn.pid")
      sh("kill -HUP `cat tmp/pids/unicorn.pid`")
      puts("Unicorn has been restarted")
    end
  else
    messages = [
      "Ray can automatically restart common application servers.",
      "Refer to the documentation for more information on auto-restart.",
      "http://johnmuhl.github.com/radiant-ray-extension/#setup-restart"
    ]
    output(messages, short=true)
    exit
  end
end

def add_remote
  hub = ENV["hub"]
  search_extensions(show = nil)
  @url.gsub!(/(http)(:\/\/github.com\/).*(\/.*)/, "git\\2" + hub + "\\3")
  extension = ENV['name']
  if File.exist?("#{@p}/#{extension}/.git")
    Dir.chdir("#{@p}/#{extension}") do
      sh("git remote add #{hub} #{@url}.git")
      sh("git fetch -q #{hub}")
      branches = `git branch -a`.split("\n")
      @new_branch = []
      branches.each do |branch|
        branch.strip!
        @new_branch << branch if branch.include?(hub)
        @current_branch = branch.gsub!(/\*\ /, "") if branch.include?("* ")
      end
      @new_branch.each do |branch|
        sh("git fetch -q #{hub} #{branch.gsub(/.*\/(.*)/, "\\1")}")
        sh("git checkout -q --track -b #{branch} #{branch}")
        sh("git checkout -q #{@current_branch}")
      end
    end
    messages = [
      "All of #{hub}'s branches have been pulled into local branches.",
      "Use your normal git workflow to inspect and merge these branches."
    ]
    output(messages)
    exit
  else
    messages = ["#{@p}/#{extension} is not a git repository."]
    output(messages)
    exit
  end
end

def pull_remote
  name = ENV["name"] if ENV[ "name" ]
  if name
    @pull_branch = []
    Dir.chdir("#{@p}/#{name}") do
      if File.exist?(".git")
        branches = `git branch`.split("\n")
        branches.each do |branch|
          branch.strip!
          @pull_branch << branch if branch.include?("/")
          @current_branch = branch.gsub!(/\*\ /, "") if branch.include?("* ")
        end
        @pull_branch.each do |branch|
          sh("git checkout -q #{branch}")
          sh("git pull -q #{branch.gsub(/(.*)\/.*/, "\\1")} #{branch.gsub(/.*\/(.*)/, "\\1")}")
          sh("git checkout -q #{@current_branch}")
        end
      else
        messages = [
          "#{@p}/#{name} is not a git repository."
        ]
        output(messages)
        exit
      end
      messages = [
        "Updated all remote branches of the #{name} extension.",
        "Use your normal git workflow to inspect and merge these branches."
      ]
      output(messages)
      exit
    end
  else
    extensions = @name ? @name.gsub(/\-/, "_") : Dir.entries(@p) - [".", "..", ".DS_Store", ".disabled", "ray"]
    extensions.each do |extension|
      Dir.chdir("#{@p}/#{extension}") do
        if File.exist?(".git")
          @pull_branch = []
          branches = `git branch`.split("\n")
          branches.each do |branch|
            branch.strip!
            @pull_branch << branch if branch.include?("/")
            @current_branch = branch.gsub!(/\*\ /, "") if branch.include?("* ")
          end
          if @pull_branch.length > 0
            @pull_branch.each do |branch|
              sh("git checkout -q #{branch}")
              sh("git pull -q #{branch.gsub(/(.*)\/.*/, "\\1")} #{branch.gsub(/.*\/(.*)/, "\\1")}")
              sh("git checkout -q #{@current_branch}")
              messages = ["Updated remote branches for the #{extension} extension."]
              output(messages)
            end
          end
        else
          messages = [
            "#{@p}/#{extension} is not a git repository."
          ]
          output(messages)
        end
      end
    end
    messages = [
      "Updated all remote branches.",
      "Use your normal git workflow to inspect and merge these branches."
    ]
    output(messages)
    exit
  end
end

def check_search_freshness
  if File.exist?("#{@r}/search.yml")
    mod_time = File.mtime("#{@r}/search.yml")
    if mod_time < Time.now - (60 * 60 * 24 * 2)
      download_search_file
    end
  else
    download_search_file
  end
end

def download_search_file
  begin
    search = open("http://github.com/johnmuhl/radiant-ray-extension/raw/master/search.yml", "User-Agent" => "open-uri").read
  rescue Exception
    messages = [
      "GitHub failed to serve the requested search file.",
      "These are usually temporary issues, just try it again."
    ]
    output(messages)
    exit
  end
  open("#{@r}/search.yml", "wb") { |f| f.write(search) }
  messages = ["Search file updated."]
  output(messages)
end

def normalize_name
  if ENV["name"].include?("-")
    @name = ENV["name"].gsub("-", "_")
  else
    @name = ENV['name']
  end
end

namespace :radiant do
  namespace :extensions do
    namespace :ray do
      task :migrate do
        puts("Ray doesn't have any migrate tasks to run.")
      end
      task :update do
        puts("Ray doesn't have any static assets to copy.")
      end
    end
  end
end
