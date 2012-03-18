# coding: utf-8

require 'test_helper'

include IRCSupport::Formatting

describe "HasColor" do
  it "should detect color codes" do
    has_color?("mIRC color \x0303green and\x0f normal").must_equal true
    has_color?("\x1b\x00\x40ecma color").must_equal true
    has_color?("\x04eeff00rgb color").must_equal true
  end
  it "should not detect any color codes" do
    has_color?("normal text").must_equal false
    has_color?("mIRC \x02bold and\x16 reverse").must_equal false
  end
end

describe "HasFormatting" do
  it "should detect formatting codes" do
    has_formatting?("mIRC \x02bold and\x16 reverse").must_equal true
  end
  it "should not detect any formatting codes" do
    has_formatting?("normal text").must_equal false
    has_formatting?("mIRC color \x0303green and\x0f normal").must_equal false
  end
end

describe "Strip" do
  it "should strip color coldes" do
    colored = "\x0304,05Hi, I am\x03 a \x03,05color\x03 \x0305junkie\x03"
    has_color?(colored).must_equal true
    stripped = strip_color(colored)
    has_color?(stripped).must_equal false
  end

  it "should strip formatting codes" do
    formatted = "This is \x02bold\x0f and this is \x1funderlined\x0f"
    has_formatting?(formatted).must_equal true
    stripped = strip_formatting(formatted)
    has_formatting?(stripped).must_equal false
  end

  it "should strip color and formatting codes" do
    form_color = "Foo \x0305\x02bar\x0f baz"
    has_color?(form_color).must_equal true
    has_formatting?(form_color).must_equal true
    stripped = strip_color(form_color)
    stripped = strip_formatting(stripped)
    has_color?(stripped).must_equal false
    has_formatting?(stripped).must_equal false
  end
end

describe "IRCFormat" do
  it "should format the string" do
    formatted = irc_format(:underline, "Hello %s!" % irc_format(:bold, "you"))
    has_color?(formatted).must_equal false
    has_formatting?(formatted).must_equal true
    colored = irc_format(:yellow, "Hello %s!" % irc_format(:blue, "you"))
    has_color?(colored).must_equal true
    has_formatting?(colored).must_equal false
    proc { irc_format(:blue, :yellow, :orange, "Foo") }.must_raise ArgumentError
  end
end
