# coding: utf-8

require 'test_helper'

include IRCSupport::Validations

describe "ValidNickname" do
  it "should say the nick is valid" do
    valid_nickname?("foobar[^]").must_equal true
    valid_nickname?("Foobar^1").must_equal true
    valid_nickname?("Fo{}o[]ba\\r-^1").must_equal true
  end
  it "should say the nick is invalid" do
    valid_nickname?("foobar[=]").must_equal false
    valid_nickname?("0Foobar^1").must_equal false
  end
end

describe "ValidChannelName" do
  it "should say the channel is valid" do
    valid_channel_name?("#fooBARæði123...iii").must_equal true
    valid_channel_name?("#foobar").must_equal true
    valid_channel_name?("#foo.bar").must_equal true
    valid_channel_name?("&foobar").must_equal true
    valid_channel_name?("-foobar", [ :- ]).must_equal true
  end
  it "should say the channel is invalid" do
    valid_channel_name?("#foo,bar").must_equal false
    valid_channel_name?("dfdsfdsf").must_equal false
    valid_channel_name?("-dfdsfdsf").must_equal false
    valid_channel_name?("#foobar", [ :k ]).must_equal false
    valid_channel_name?("#chan"+"f"*200).must_equal false
  end
end

