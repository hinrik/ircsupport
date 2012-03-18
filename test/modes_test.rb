# coding: utf-8

require 'test_helper'

include IRCSupport::Modes

describe "Modelines" do
  it "should condense the mode line" do
    condense_modes('+o-v-o-o+v-o+o+o').must_equal '+o-voo+v-o+oo'
  end

  it "should generate the mode changes" do
    diff_modes('ailowz','i').must_equal '-alowz'
    diff_modes('i','ailowz').must_equal '+alowz'
    diff_modes('i','alowz').must_equal '-i+alowz'
  end

  it "should parse the modes" do
    parse_modes('+i-m').must_equal [
      { set: true, mode: 'i' },
      { set: false, mode: 'm' },
    ]
    parse_channel_modes(['+i+k+l', 'secret', '5']).must_equal [
      { set: true, mode: 'i' },
      { set: true, mode: 'k', argument: 'secret' },
      { set: true, mode: 'l', argument: 5 },
    ]
  end

  it "should fail to parse the modes" do
    proc { parse_channel_modes('+i-_')}.must_raise ArgumentError
  end
end

