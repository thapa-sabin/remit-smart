require "test_helper"

class CorridorsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get corridors_show_url
    assert_response :success
  end
end
