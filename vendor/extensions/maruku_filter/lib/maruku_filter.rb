require 'maruku'

class MarukuFilter < TextFilter
  description_file File.dirname(__FILE__) + "/../maruku.html"
  def filter(text)
    Maruku.new(text).to_html
  end
end
