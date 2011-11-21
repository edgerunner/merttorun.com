class MarukuFilterExtension < Radiant::Extension
  version "0.1"
  description "Adds support to Maruku: A Markdown-superset interpreter"
  url "http://maruku.rubyforge.org/"
  
  def activate
    MarukuFilter
  end
end
