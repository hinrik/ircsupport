# coding: utf-8

require 'test_helper'

include IRCSupport::Case

describe "IRCUpcase" do
  it "should put string into IRC uppercase" do
    irc_upcase("simple").must_equal "SIMPLE"
    irc_upcase("c0mpl^{x}").must_equal "C0MPL~[X]"
    irc_upcase("c0mpl~[x]").must_equal "C0MPL~[X]"
    irc_upcase("c0mpl~{x}").must_equal "C0MPL~[X]"
    irc_upcase("c0mpl|{x}").must_equal "C0MPL\\[X]"
    irc_upcase("c0mpl^{x}", :'strict-rfc1459').must_equal "C0MPL^[X]"
    irc_upcase("c0mpl^{x}", :ascii).must_equal "C0MPL^{X}"
    proc { irc_upcase("c0mpl^{x}", :foobar) }.must_raise ArgumentError
  end
end

describe "IRCDowncase" do
  it "should put string into IRC lowercase" do
    irc_downcase("SIMPLE").must_equal "simple"
    irc_downcase("C0MPL~[X]").must_equal "c0mpl^{x}"
    irc_downcase("C0MPL^{X}").must_equal "c0mpl^{x}"
    irc_downcase("C0MPL^[X]").must_equal "c0mpl^{x}"
    irc_downcase("C0MPL\\[X]").must_equal "c0mpl|{x}"
    irc_downcase("C0MPL~[x]", :'strict-rfc1459').must_equal "c0mpl~{x}"
    irc_downcase("c0mpl^{x}", :ascii).must_equal "c0mpl^{x}"
    proc { irc_downcase("c0mpl^{x}", :foobar) }.must_raise ArgumentError
  end
end

describe "IRCEql" do
  it "should say they are equal in IRC-case" do
    irc_eql?('C0MPL~[X]', 'c0mpl^{x}').must_equal true
  end
  it "should say they are unequal in IRC-case" do
    irc_eql?('C0MPL~[X]', 'c0mpl^{x}', :'strict-rfc1459').must_equal false
    irc_eql?('C0MPL|[X]', 'c0mpl~{x}').must_equal false
  end
end
