require File.dirname(__FILE__) + '/../test_helper'

class MarukuFilterTest < Test::Unit::TestCase

  def test_filter_name
    assert_equal 'Maruku', MarukuFilter.filter_name
  end

  def test_filter
    assert_equal '<p><strong>strong</strong></p>', MarukuFilter.filter('**strong**')
  end
  
 end
