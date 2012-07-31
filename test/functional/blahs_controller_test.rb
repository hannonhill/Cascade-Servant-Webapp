require 'test_helper'

class BlahsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:blahs)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create blah" do
    assert_difference('Blah.count') do
      post :create, :blah => { }
    end

    assert_redirected_to blah_path(assigns(:blah))
  end

  test "should show blah" do
    get :show, :id => blahs(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => blahs(:one).to_param
    assert_response :success
  end

  test "should update blah" do
    put :update, :id => blahs(:one).to_param, :blah => { }
    assert_redirected_to blah_path(assigns(:blah))
  end

  test "should destroy blah" do
    assert_difference('Blah.count', -1) do
      delete :destroy, :id => blahs(:one).to_param
    end

    assert_redirected_to blahs_path
  end
end
