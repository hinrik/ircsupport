# coding: utf-8

require 'test_helper'

include IRCSupport::Encoding

describe "Encoding" do
  utf8 = "lúði"
  cp1252 = "l\xFA\xF0i"

  it "should decode correctly" do
    decode_irc(utf8).must_equal utf8
    decode_irc(utf8, 'UTF-8').must_equal utf8
    decode_irc(cp1252).must_equal utf8
  end

  it "should encode correctly" do
    if RUBY_ENGINE == "rbx"
      skip("Encoding support is incomplete on Rubinius")
    end
    encode_irc(utf8).bytes.to_a.must_equal cp1252.bytes.to_a
    encode_irc(utf8, 'UTF-8').bytes.to_a.must_equal utf8.bytes.to_a
  end
end
