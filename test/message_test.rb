# coding: utf-8

require 'test_helper'
require 'ipaddr'

traffic = [
  [
    'CAP ACK :identify-msg',
    ->(msg) {
      msg.capabilities.must_equal({
        "identify-msg" => [:enable]
      })
    }
  ],
  [
    ':adams.freenode.net 001 dsfdsfdsf :Welcome to the freenode Internet Relay Chat Network dsfdsfdsf',
    ->(msg) {
      msg.prefix.must_equal 'adams.freenode.net'
      msg.command.must_equal '001'
      msg.args[0].must_equal 'dsfdsfdsf'
      msg.args[1].must_equal 'Welcome to the freenode Internet Relay Chat Network dsfdsfdsf'
      msg.type.must_equal :'001'
      msg.name.must_equal 'RPL_WELCOME'
      msg.is_error?.must_equal false
    },
  ],

  [
    ':adams.freenode.net 005 dsfdsfdsf CHANTYPES=# EXCEPTS INVEX CHANMODES=eIbq,k,flj,CFLMPQcgimnprstz CHANLIMIT=#:120 PREFIX=(ov)@+ MAXLIST=bqeI:100 MODES=4 NETWORK=freenode KNOCK STATUSMSG=@+ CALLERID=g :are supported by this server',
    ->(msg) {
      msg.args[1].must_equal 'CHANTYPES=#'
      msg.args[13].must_equal 'are supported by this server'
      msg.isupport["MODES"].must_equal 4
      msg.isupport["STATUSMSG"].must_equal %w{@ +}.to_set
      msg.isupport["CHANTYPES"].must_equal %w{#}.to_set
      msg.isupport["CHANMODES"].must_equal({
        'A' => %w{e I b q}.to_set,
        'B' => %w{k}.to_set,
        'C' => %w{f l j}.to_set,
        'D' => %w{C F L M P Q c g i m n p r s t z}.to_set,
      })
      msg.isupport["CHANLIMIT"].must_equal({ '#' => 120 })
      msg.isupport["PREFIX"].must_equal({ 'o' => '@', 'v' => '+' })
      msg.isupport["NETWORK"].must_equal 'freenode'
    },
  ],
  [
    ':adams.freenode.net 005 dsfdsfdsf CASEMAPPING=rfc1459 CHARSET=ascii NICKLEN=16 CHANNELLEN=50 TOPICLEN=390 ETRACE CPRIVMSG CNOTICE DEAF=D MONITOR=100 FNC TARGMAX=NAMES:1,LIST:1,KICK:1,WHOIS:1,PRIVMSG:4,NOTICE:4,ACCEPT:,MONITOR: :are supported by this server',
    ->(msg) {
      msg.isupport["CASEMAPPING"].must_equal :rfc1459
      msg.isupport["TARGMAX"].must_equal({
        'NAMES'   => 1,
        'LIST'    => 1,
        'KICK'    => 1,
        'WHOIS'   => 1,
        'PRIVMSG' => 4,
        'NOTICE'  => 4,
        'ACCEPT'  => 0,
        'MONITOR' => 0,
      })
    },
  ],
  [
    ':adams.freenode.net 353 dsfdsfdsf @ #foo4321 :dsfdsfdsf @literal',
    ->(msg) {
      msg.channel.must_equal '#foo4321'
      msg.channel_type.must_equal '@'
      msg.users.must_equal [[nil, 'dsfdsfdsf'], %w{@ literal}]
    },
  ],
  [
    ':adams.freenode.net 352 dsfdsfdsf #foo4321 ~hinrik 191-108-22-46.fiber.hringdu.is adams.freenode.net dsfdsfdsf H :0 Hinrik Örn Sigurðsson',
    ->(msg) {
      msg.target.must_equal '#foo4321'
      msg.username.must_equal '~hinrik'
      msg.hostname.must_equal '191-108-22-46.fiber.hringdu.is'
      msg.server.must_equal 'adams.freenode.net'
      msg.nickname.must_equal 'dsfdsfdsf'
      msg.away.must_equal false
      msg.hops.must_equal 0
      msg.realname.must_equal 'Hinrik Örn Sigurðsson'
    }
  ],
  [
    ':NickServ!NickServ@services. NOTICE dsfdsfdsf :+This nickname is registered. Please choose a different nickname, or identify via /msg NickServ identify <password>.',
    ->(msg) {
      msg.type.must_equal :message
      msg.is_notice?.must_equal true
      msg.sender.must_equal 'NickServ!NickServ@services.'
      msg.identified?.must_equal true
      msg.message.must_equal 'This nickname is registered. Please choose a different nickname, or identify via /msg NickServ identify <password>.'
    }
  ],
  [
    ':literal!hinrik@w.nix.is INVITE dsfdsfdsf :#foo4321',
    ->(msg) {
      msg.inviter.must_equal 'literal!hinrik@w.nix.is'
      msg.channel.must_equal '#foo4321'
    },
  ],
  [
    ':literal!hinrik@w.nix.is PRIVMSG #foo4321 :-dsfdsfsdfds',
    ->(msg) {
      msg.channel.must_equal '#foo4321'
      msg.identified?.must_equal false
    },
  ],
  [
    ':literal!hinrik@w.nix.is PRIVMSG #foo4321 :+dsfdsfsdfds',
    ->(msg) {
      msg.identified?.must_equal true
    },
  ],
  [
    ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01-ACTION dsfdsfsdfds\x01",
    ->(msg) {
      msg.identified?.must_equal false
      msg.is_action?.must_equal true
    },
  ],
  [
    ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01+ACTION dsfdsfsdfds\x01",
    ->(msg) {
      msg.identified?.must_equal true
      msg.is_action?.must_equal true
    },
  ],
  [
    ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01FOOBAR dsfdsfsdfds\x01",
    ->(msg) {
      msg.type.must_equal :ctcp_foobar
      msg.ctcp_type.must_equal :foobar
      msg.ctcp_args.must_equal 'dsfdsfsdfds'
    },
  ],
  [
    ":literal!hinrik@w.nix.is NOTICE #foo4321 :\x01FOOBAR dsfdsfsdfds\x01",
    ->(msg) {
      msg.type.must_equal :ctcpreply_foobar
      msg.ctcp_type.must_equal :foobar
      msg.ctcp_args.must_equal 'dsfdsfsdfds'
    },
  ],
  [
    ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01DCC FOO dsfdsfsdfds\x01",
    ->(msg) {
      msg.type.must_equal :dcc_foo
      msg.dcc_type.must_equal :foo
      msg.sender.must_equal 'literal!hinrik@w.nix.is'
      msg.dcc_args.must_equal 'dsfdsfsdfds'
    },
  ],
  [
    ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01DCC CHAT dummy 3232246293 12345\x01",
    ->(msg) {
      msg.address.must_equal IPAddr.new(3232246293, Socket::AF_INET)
      msg.port.must_equal 12345
    },
  ],
  [
    ":literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01DCC SEND foobar.txt 3232246293 12345 5000\x01",
    ->(msg) {
      msg.filename.must_equal Pathname.new('foobar.txt')
      msg.address.must_equal IPAddr.new(3232246293, Socket::AF_INET)
      msg.port.must_equal 12345
      msg.size.must_equal 5000
    },
  ],
  [
    %Q{:literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01DCC SEND "foo and bar.txt" 3232246293 12345 5000\x01},
    ->(msg) {
      msg.filename.must_equal Pathname.new('foo and bar.txt')
      msg.address.must_equal IPAddr.new(3232246293, Socket::AF_INET)
      msg.port.must_equal 12345
      msg.size.must_equal 5000
    },
  ],
  [
    %Q{:literal!hinrik@w.nix.is PRIVMSG #foo4321 :\x01DCC ACCEPT "foo and bar.txt" 12345 1000\x01},
    ->(msg) {
      msg.filename.must_equal Pathname.new('foo and bar.txt')
      msg.port.must_equal 12345
      msg.position.must_equal 1000
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is JOIN #foo4321',
    ->(msg) {
      msg.joiner.must_equal 'dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is'
      msg.channel.must_equal '#foo4321'
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is PART #foo4321',
    ->(msg) {
      msg.parter.must_equal 'dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is'
      msg.channel.must_equal '#foo4321'
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is PART #foo4321 :',
    ->(msg) {
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is PART #foo4321 :bye!',
    ->(msg) {
      msg.message.must_equal 'bye!'
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is KICK #foo4321 boring_person :bye!',
    ->(msg) {
      msg.kicker.must_equal 'dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is'
      msg.kickee.must_equal 'boring_person'
      msg.message.must_equal 'bye!'
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is KICK #foo4321 boring_person :',
    ->(msg) {
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is KICK #foo4321 boring_person',
    ->(msg) {
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is NICK new_name',
    ->(msg) {
      msg.changer.must_equal 'dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is'
      msg.nickname.must_equal 'new_name'
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is TOPIC #foo4321 :fooo',
    ->(msg) {
      msg.changer.must_equal 'dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is'
      msg.channel.must_equal '#foo4321'
      msg.topic.must_equal 'fooo'
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is TOPIC #foo4321 :',
    ->(msg) {
      msg.topic.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is TOPIC #foo4321',
    ->(msg) {
      msg.topic.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is QUIT :gone',
    ->(msg) {
      msg.quitter.must_equal 'dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is'
      msg.message.must_equal 'gone'
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is QUIT :',
    ->(msg) {
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is QUIT',
    ->(msg) {
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is PING',
    ->(msg) {
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is PING :',
    ->(msg) {
      msg.message.must_equal nil
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is PING :123',
    ->(msg) {
      msg.message.must_equal '123'
    },
  ],
  [
    'NOTICE :foo bar',
    ->(msg) {
      msg.type.must_equal :server_notice
      msg.sender.must_equal nil
      msg.target.must_equal nil
      msg.message.must_equal 'foo bar'
    },
  ],
  [
    ':fooserver NOTICE AUTH :foo bar',
    ->(msg) {
      msg.type.must_equal :server_notice
      msg.sender.must_equal 'fooserver'
      msg.target.must_equal 'AUTH'
      msg.message.must_equal 'foo bar'
    },
  ],
  [
    ':foo-service NOTICE :foo bar',
    ->(msg) {
      msg.type.must_equal :server_notice
      msg.sender.must_equal 'foo-service'
      msg.message.must_equal 'foo bar'
    },
  ],
  [
    'CAP LS :foo -bar ~baz ~=quux',
    ->(msg) {
      msg.multipart.must_equal false
      msg.type.must_equal :cap_ls
      msg.subcommand.must_equal 'LS'
      msg.reply.must_equal 'foo -bar ~baz ~=quux'
      msg.capabilities.must_equal({
        'foo' => [:enable],
        'bar' => [:disable],
        'baz' => [:enable],
        'quux' => [:enable, :sticky],
      })
    }
  ],
  [
    'CAP LS * :foo -bar ~baz ~=quux',
    ->(msg) {
      msg.multipart.must_equal true
    }
  ],
  [
    'ERROR :Closing Link: 191-108-22-46.fiber.hringdu.is (Client Quit)',
    ->(msg) {
      msg.error.must_equal 'Closing Link: 191-108-22-46.fiber.hringdu.is (Client Quit)'
    }
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is MODE +i',
    ->(msg) {
      msg.type.must_equal :user_mode_change
      msg.mode_changes.must_equal [
        {
          mode: 'i',
          set: true,
        },
      ]
    },
  ],
  [
    ':dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is MODE #foo4321 +tlk 300 foo',
    ->(msg) {
      msg.type.must_equal :channel_mode_change
      msg.changer.must_equal 'dsfdsfdsf!~hinrik@191-108-22-46.fiber.hringdu.is'
      msg.channel.must_equal '#foo4321'
      msg.mode_changes.must_equal [
        {
          mode: 't',
          set: true,
        },
        {
          mode: 'l',
          set: true,
          argument: 300,
        },
        {
          mode: 'k',
          set: true,
          argument: 'foo',
        },
      ]
    },
  ],
  [
    'FOO BAR :baz',
    ->(msg) {
      msg.type.must_equal :foo
      msg.prefix.must_equal nil
      msg.args.must_equal ['BAR', 'baz']
    }
  ],
  [
    'CAP ACK :-identify-msg',
    ->(msg) {
      msg.capabilities.must_equal({
        "identify-msg" => [:disable]
      })
    }
  ],
  [
    ':literal!hinrik@w.nix.is PRIVMSG #foo4321 :dsfdsfsdfds',
    ->(msg) {
      msg.respond_to?(:identified?).must_equal false
    },
  ],
]

describe "IRCTraffic" do
  parser = IRCSupport::Parser.new
  it "should return correct messages for the IRC traffic" do
    traffic.each_with_index do |line_info, index|
      line, handler = *line_info
      parsed = parser.parse(line)
      handler.call(parsed)
    end
  end
end
