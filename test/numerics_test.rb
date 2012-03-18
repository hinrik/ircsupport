# coding: utf-8

require 'test_helper'

include IRCSupport::Numerics

describe "Numerics" do
  it "should recognize numeric 001" do
    numeric_to_name('001').must_equal 'RPL_WELCOME'
  end
  it "should recognize command" do
    name_to_numeric('RPL_WELCOME').must_equal '001'
  end
end
