namespace :radiant do
  namespace :extensions do
    namespace :redirect do
      
      desc "Runs the migration of the Redirect extension"
      task :migrate => :environment do
        require 'radiant/extension_migrator'
        if ENV["VERSION"]
          RedirectExtension.migrator.migrate(ENV["VERSION"].to_i)
        else
          RedirectExtension.migrator.migrate
        end
      end
      
      desc "Copies public assets of the Redirect to the instance public/ directory."
      task :update => :environment do
        is_svn_or_dir = proc {|path| path =~ /\.svn/ || File.directory?(path) }
        puts "Copying assets from RedirectExtension"
        Dir[RedirectExtension.root + "/public/**/*"].reject(&is_svn_or_dir).each do |file|
          path = file.sub(RedirectExtension.root, '')
          directory = File.dirname(path)
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end
      end  
    end
  end
end
