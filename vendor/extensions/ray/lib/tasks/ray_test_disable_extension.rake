namespace :ray do
  namespace :test do
    task :disable do
      test_disable_extension
    end
  end
end

def test_disable_extension
  extensions = Dir.entries("vendor/extensions") - [".", "..", ".DS_Store", ".disabled", "ray"]
  extensions.each do |extension|
    begin
      sh "rake ray:extension:disable name=#{extension} --trace"
    rescue Exception => error
      puts "FAILED!\n#{error}"
      exit
    end
  end
end