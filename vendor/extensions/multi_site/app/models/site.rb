class Site < ActiveRecord::Base
  acts_as_list
  default_scope :order => 'position ASC'

  class << self
    def find_for_host(hostname = '')
      default, normal = find(:all).partition {|s| s.domain.blank? }
      matching = normal.find do |site|
        hostname == site.base_domain || hostname =~ Regexp.compile(site.domain)
      end
      matching || default.first
    end
  end
  
  belongs_to :homepage, :class_name => "Page", :foreign_key => "homepage_id"
  validates_presence_of :name, :base_domain
  validates_uniqueness_of :domain
  
  after_create :create_homepage
  after_save :reload_routes
  
  def url(path = "/")
    uri = URI.join("http://#{self.base_domain}", path)
    uri.to_s
  end
  
  def dev_url(path = "/")
    uri = URI.join("http://#{Radiant::Config['dev.host']|| 'dev'}.#{self.base_domain}", path)
    uri.to_s
  end
  
  def create_homepage
    if self.homepage_id.blank?
        self.homepage = self.build_homepage(:title => "#{self.name} Homepage", 
                           :slug => "#{self.name.to_slug}", :breadcrumb => "Home")
        default_status = Radiant::Config['defaults.page.status']
        self.homepage.status = Status[default_status] if default_status
        default_parts = Radiant::Config['defaults.page.parts'].to_s.strip.split(/\s*,\s*/)
        default_parts.each do |name|
          self.homepage.parts << PagePart.new(:name => name, :filter_id => Radiant::Config['defaults.page.filter'])
        end
        save
    end
  end
  
  def reload_routes
    ActionController::Routing::Routes.reload
  end
end
