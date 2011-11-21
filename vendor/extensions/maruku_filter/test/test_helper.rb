unless defined? RADIANT_ROOT
  ENV["RAILS_ENV"] = "test"
  require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../")}/config/environment"
end
require "#{RADIANT_ROOT}/test/test_helper"

class Test::Unit::TestCase
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures = false
end
