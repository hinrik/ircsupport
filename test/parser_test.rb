# coding: utf-8

require 'test_helper'

describe "Parse" do
  parser = IRCSupport::Parser.new
  raw_line = ":pretend.dancer.server 005 CPAN MODES=4 CHANLIMIT=#:20 NICKLEN=16 USERLEN=10 HOSTLEN=63 TOPICLEN=450 KICKLEN=450 CHANNELLEN=30 KEYLEN=23 CHANTYPES=# PREFIX=(ov)@+ CASEMAPPING=ascii CAPAB IRCD=dancer :are available on this server"
  line = parser.decompose(raw_line)
  it "should parse the server message" do
    line.prefix.must_equal "pretend.dancer.server"
    line.command.must_equal "005"
    line.args.count.must_equal 16
    line.args[0].must_equal "CPAN"
    line.args[15].must_equal "are available on this server"
    parser.isupport["MODES"].must_equal 4
  end

  it 'should allow trailing \r\n or \n' do
    raw_rn = "#{raw_line}\x0d\x0a"
    parser.decompose(raw_rn)[:command].must_equal "005"
    raw_n = "#{raw_line}\x0a"
    parser.decompose(raw_n)[:command].must_equal "005"
  end

  it "should compose the server message" do
    irc_line = parser.compose(line)
    irc_line.must_equal raw_line
  end

  it "should fail to compose the server message" do
    proc { parser.compose(IRCSupport::Line.new) }.must_raise ArgumentError
    proc { parser.compose(IRCSupport::Line.new("foo")) }.must_raise ArgumentError
    proc { parser.compose(IRCSupport::Line.new(nil, "bar", ['a b', 'c'])) }.must_raise ArgumentError
  end

  it "should fail to decompoes the IRC line" do
    proc { parser.parse("+") }.must_raise ArgumentError
  end
end

describe "CTCP" do
  parser = IRCSupport::Parser.new
  it "should quote the CTCP message" do
    parser.ctcp_quote('ACTION', 'dances').must_equal "\x01ACTION dances\x01"
  end

  it "should fail to parse the CTCP message" do
    invalid = ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01..,, dsfdsfsdfds\x01"
    proc { parser.parse(invalid) }.must_output nil, "Received malformed CTCP from literal!hinrik@w.nix.is: ..,, dsfdsfsdfds\n"
  end

  it "should fail to parse the DCC request" do
    invalid = ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01DCC ..,,\x01"
    proc { parser.parse(invalid) }.must_output nil, "Received malformed DCC request from literal!hinrik@w.nix.is: DCC ..,,\n"
  end

  it "should handle unbalanced NULs" do
    unbalanced = ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01ACTION jumps\x01foo\x01"
    msg = parser.parse(unbalanced)
    msg.message.must_equal 'jumps'
  end
end
