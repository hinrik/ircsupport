IRCSupport
==========

[![Gem Version](https://badge.fury.io/rb/ircsupport.png)](http://badge.fury.io/rb/ircsupport)
[![Build Status](https://secure.travis-ci.org/hinrik/ircsupport.png?branch=master)](http://travis-ci.org/hinrik/ircsupport)
[![Dependency Status](https://gemnasium.com/hinrik/ircsupport.png)](https://gemnasium.com/hinrik/ircsupport)
[![Code Climate](https://codeclimate.com/github/hinrik/ircsupport.png)](https://codeclimate.com/github/hinrik/ircsupport)
[![Coverage Status](https://coveralls.io/repos/hinrik/ircsupport/badge.png?branch=master)](https://coveralls.io/r/hinrik/ircsupport)

IRCSupport provides everything you need to work with the IRC protocol and its
widely-used extensions. It is meant to be a building block for higher-level
libraries that use IRC (clients or servers). There are a bunch of IRC
client/bot libraries for Ruby out there, and they all implement their own
stuff for dealing with the IRC protocol. Why not keep it in one place?

Features
--------

* __Complete:__ Includes support for all protocol standards used by modern
  IRC clients and servers, including:
 * RFC1459
 * RFC2812 & RFC2813
 * CTCP
 * DCC (CHAT, SEND, ACCEPT, RESUME)
 * RPL\_ISUPPORT (draft-brocklesby-irc-isupport-03)
 * CAP capabilities extension (draft-mitchell-irc-capabilities-02)
 * mIRC/ECMA-48/RGB color and formatting codes
* __Tested:__ A heavy emphasis is placed on testing the code. It generally
  has 100% test coverage.
* __Flexible:__ The tools provided by IRCSupport are flexible and modular,
  and should encourage reuse.

Usage
-----

Here are some examples of using IRCSupport:

```ruby
require 'ircsupport'

line = ':foo!bar@baz.com PRIVMSG #the_room :Greetings, everyone!'
irc_parser = IRCSupport::Parser.new
msg = irc_parser.parse(line)

msg.channel
# => '#the_room'

msg.sender
# => 'foo!bar@baz'

msg.is_action?
# => false

msg.type
# => :message

IRCSupport::Validations.valid_nick_name?("Foo{}Bar[]")
# => true

IRCSupport::Validations.valid_nick_name?("123FooBar")
# => false

IRCSupport::Numerics.numeric_to_name('005')
# => 'RPL_ISUPPORT'

# any module can also be mixed into your class
include IRCSupport::Numerics
numeric_to_name('001')
# => 'RPL_WELCOME'
```

See the [API documentation](http://rubydoc.info/github/hinrik/ircsupport) for
more details.

Components
----------

### [`IRCSupport::Parser`](http://rubydoc.info/gems/ircsupport/IRCSupport/Parser)

This class is a complete parser for the IRC protocol. It can provide you with
rich objects which encapsulate all the information of a message in handy
methods.

### [`IRCSupport::Case`](http://rubydoc.info/gems/ircsupport/IRCSupport/Case)

A module that provides functions that conversion between various IRC
casemappings.

### [`IRCSupport::Encoding`](http://rubydoc.info/gems/ircsupport/IRCSupport/Encoding)

A module that provides functions to encode or decode IRC messages.

### [`IRCSupport::Formatting`](http://rubydoc.info/gems/ircsupport/IRCSupport/Formatting)

A module that provides functions for detecting, stripping, and constructing
strings with IRC color and formatting codes.

### [`IRCSupport::Masks`](http://rubydoc.info/gems/ircsupport/IRCSupport/Masks)

A module that provides functions to deal with IRC masks.

### [`IRCSupport::Modes`](http://rubydoc.info/gems/ircsupport/IRCSupport/Modes)

A module that provides functions to work with mode strings.

### [`IRCSupport::Numerics`](http://rubydoc.info/gems/ircsupport/IRCSupport/Numerics)

A module that provides functions to look up the names of IRC numerics and
vice versa.

### [`IRCSupport::Validations`](http://rubydoc.info/gems/ircsupport/IRCSupport/Validations)

A module that provides functions to validate various IRC strings.

Contributing
------------

* Fork this repository on github
* Make your changes and send me a pull request
* If I like them I'll merge them
* If I've accepted a patch, feel free to ask for commit access

Kudos
-----
Those go to the authors of the [`IRC::Utils`](https://metacpan.org/module/IRC::Utils)
Perl module, on which much of this library's functionality is based. Same for
the authors of [`cinch`](https://github.com/cinchrb/cinch), from which a few
functions were borrowed.

License
-------

Copyright (c) 2012 Hinrik Örn Sigurðsson. Distributed under the MIT License.
See LICENSE.txt for further details.
