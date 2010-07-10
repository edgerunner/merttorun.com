require File.dirname(__FILE__) + '/../spec_helper'

describe Redirection do
  before(:each) do
    @redirection = Redirection.new
  end

  it "should be valid" do
    @redirection.should be_valid
  end
end
