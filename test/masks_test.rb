# coding: utf-8

require 'test_helper'

include IRCSupport::Masks

describe "Masks" do
  it "should normalize the mask" do
    normalize_mask('*@*').must_equal '*!*@*'
    normalize_mask('foo*').must_equal 'foo*!*@*'
  end

  banmask = 'stalin*!*@*'

  it "should match the mask" do
    match = 'stalin!joe@kremlin.ru'
    matches_mask(banmask, match).must_equal true
    result = matches_mask_array([banmask], [match])
    result.must_be_kind_of Hash
    result.must_include 'stalin*!*@*'
    result['stalin*!*@*'].must_be_kind_of Array
    result['stalin*!*@*'].must_include "stalin!joe@kremlin.ru"
  end

  it "should not match the mask" do
    no_match = 'BinGOs!foo@blah.com'
    matches_mask(banmask, no_match).must_equal false
    no_result = matches_mask_array([banmask], [no_match])
    no_result.must_be_kind_of Hash
    no_result.must_be_empty
  end

  it "should fail miserably" do
    proc { matches_mask('$r:Lee*', 'foo') }.must_raise ArgumentError
  end
end
