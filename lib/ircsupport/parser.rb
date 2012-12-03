require 'ircsupport/message'

module IRCSupport
  class Parser
    # @private
    @@eol         = '\x00\x0a\x0d'
    # @private
    @@space       = / +/
    # @private
    @@maybe_space = / */
    # @private
    @@non_space   = /[^ ]+/
    # @private
    @@numeric     = /[0-9]{3}/
    # @private
    @@command     = /[a-zA-Z]+/
    # @private
    @@irc_name    = /[^#@@eol :][^#@@eol ]*/
    # @private
    @@irc_line    = /
      \A
      (?: : (?<prefix> #@@non_space ) #@@space )?
      (?<command> #@@numeric | #@@command )
      (?: #@@space (?<args> #@@irc_name (?: #@@space #@@irc_name )* ) )?
      (?: #@@space : (?<trailing_arg> [^#@@eol]* ) | #@@maybe_space )?
      \z
    /x
    # @private
    @@low_quote_from = /[\x00\x0a\x0d\x10]/
    # @private
    @@low_quote_to = {
      "\x00" => "\x100",
      "\x0a" => "\x10n",
      "\x0d" => "\x10r",
      "\x10" => "\x10\x10",
    }
    # @private
    @@low_dequote_from = /\x10[0nr\x10]/
    # @private
    @@low_dequote_to = {
      "\x100" => "\x00",
      "\x10n" => "\x0a",
      "\x10r" => "\x0d",
      "\x10\x10" => "\x10",
    }
    # @private
    @@default_isupport = {
      "PREFIX"    => {"o" => "@", "v" => "+"},
      "CHANTYPES" => ["#"],
      "CHANMODES" => {
        "A" => ["b"],
        "B" => ["k"],
        "C" => ["l"],
        "D" => %w[i m n p s t r]
      },
      "MODES"       => 1,
      "NICKLEN"     => 999,
      "MAXBANS"     => 999,
      "TOPICLEN"    => 999,
      "KICKLEN"     => 999,
      "CHANNELLEN"  => 999,
      "CHIDLEN"     => 5,
      "AWAYLEN"     => 999,
      "MAXTARGETS"  => 1,
      "MAXCHANNELS" => 999,
      "CHANLIMIT"   => {"#" => 999},
      "STATUSMSG"   => ["@", "+"],
      "CASEMAPPING" => :rfc1459,
      "ELIST"       => [],
      "MONITOR"     => 0,
    }

    # The isupport configuration of the IRC server.
    # The configuration will be seeded with sane defaults, and updated in
    # response to parsed {IRCSupport::Message::Numeric005 `005`} messages.
    # @return [Hash]
    attr_reader :isupport

    # A list of currently enabled capabilities.
    # It will be updated in response to parsed {IRCSupport::Message::CAP::ACK `CAP ACK`} messages.
    # @return [Array]
    attr_reader :capabilities

    # @private
    def initialize
      @isupport = @@default_isupport
      @capabilities = []
    end

    # Perform low-level parsing of an IRC protocol line.
    # @param [String] line An IRC protocol line you wish to decompose.
    # @return [Hash] A decomposed IRC protocol line with 3 keys:
    #   `command`, the IRC command; `prefix`, the prefix to the
    #   command, if any; `args`, an array of any arguments to the command
    def decompose_line(line)
      if line =~ @@irc_line
        c = $~
        elems = {}
        elems[:prefix] = c[:prefix] if c[:prefix]
        elems[:command] = c[:command].upcase
        elems[:args] = []
        elems[:args].concat c[:args].split(@@space) if c[:args]
        elems[:args] << c[:trailing_arg] if c[:trailing_arg]
      else
        raise ArgumentError, "Line is not IRC protocol: #{line}"
      end

      return elems
    end

    # Compose an IRC protocol line.
    # @param [Hash] elems The attributes of the message (as returned
    #   by {#decompose_line}).
    # @return [String] An IRC protocol line.
    def compose_line(elems)
      line = ''
      line << ":#{elems[:prefix]} " if elems[:prefix]
      if !elems[:command]
        raise ArgumentError, "You must specify a command"
      end
      line << elems[:command]

      if elems[:args]
        elems[:args].each_with_index do |arg, idx|
          line << ' '
          if idx != elems[:args].count-1 and arg.match(@@space)
            raise ArgumentError, "Only the last argument may contain spaces"
          end
          if idx == elems[:args].count-1
            line << ':' if arg.match(@@space)
          end
          line << arg
        end
      end

      return line
    end

    # Parse an IRC protocol line into a complete message object.
    # @param [String] line An IRC protocol line.
    # @return [IRCSupport::Message] A parsed message object.
    def parse(line)
      elems = decompose_line(line)
      elems[:isupport] = @isupport
      elems[:capabilities] = @capabilities

      if elems[:command] =~ /^(PRIVMSG|NOTICE)$/ && elems[:args][1] =~ /\x01/
        return handle_ctcp_message(elems)
      end

      if elems[:command] =~ /^\d{3}$/
        msg_class = "Numeric"
      elsif elems[:command] == "MODE"
        if @isupport['CHANTYPES'].include? elems[:args][0][0]
          msg_class = "ChannelModeChange"
        else
          msg_class = "UserModeChange"
        end
      elsif elems[:command] == "NOTICE" && (!elems[:prefix] || elems[:prefix] !~ /!/)
        msg_class = "ServerNotice"
      elsif elems[:command] =~ /^(PRIVMSG|NOTICE)$/
        msg_class = "Message"
        elems[:is_notice] = true if elems[:command] == "NOTICE"
        if @isupport['CHANTYPES'].include? elems[:args][0][0]
          elems[:is_public] = true
        end
        if @capabilities.include?('identify-msg')
          elems[:args][1], elems[:identified] = split_idmsg(elems[:args][1])
        end
      elsif elems[:command] == "CAP" && %w{LS LIST ACK}.include?(elems[:args][0])
        msg_class = "CAP::#{elems[:args][0]}"
      else
        msg_class = elems[:command]
      end

      begin
        if msg_class == "Numeric"
          begin
            msg_const = constantize("IRCSupport::Message::Numeric#{elems[:command]}")
          rescue
            msg_const = constantize("IRCSupport::Message::#{msg_class}")
          end
        else
          begin
            msg_const = constantize("IRCSupport::Message::#{msg_class}")
          rescue
            msg_const = constantize("IRCSupport::Message::#{msg_class.capitalize}")
          end
        end
      rescue
        msg_const = constantize("IRCSupport::Message")
      end

      message = msg_const.new(elems)

      if message.type == '005'
        @isupport.merge! message.isupport
      elsif message.type == 'cap_ack'
        message.capabilities.each do |capability, options|
          if options.include?(:disable)
            @capabilities = @capabilities - [capability]
          elsif options.include?(:enable)
            @capabilities = @capabilities + [capability]
          end
        end
      end

      return message
    end

    # CTCP-quote a message.
    # @param [String] type The CTCP type.
    # @param [String] message The text of the CTCP message.
    # @return [String] A CTCP-quoted message.
    def ctcp_quote(type, message)
      line = low_quote(message)
      line.gsub!(/\x01/, '\a')
      return "\x01#{type} #{line}\x01"
    end

    private

    # from ActiveSupport
    def constantize(camel_cased_word)
      names = camel_cased_word.split('::')
      names.shift if names.empty? || names.first.empty?

      constant = Object
      names.each do |name|
        constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
      end
      constant
    end

    def split_idmsg(line)
      identified, line = line.split(//, 2)
      identified = identified == '+' ? true : false
      return line, identified
    end

    def handle_ctcp_message(elems)
      ctcp_type = elems[:command] == 'PRIVMSG' ? 'CTCP' : 'CTCPReply'
      ctcps, texts = ctcp_dequote(elems[:args][1])

      # We only process the first CTCP, ignoring extra CTCPs and any
      # non-CTCPs. Those who send anything in addition to that first CTCP
      # are probably up to no good (e.g. trying to flood a bot by having it
      # reply to 20 CTCP VERSIONs at a time).
      ctcp = ctcps.first

      if @capabilities.include?('identify-msg') && ctcp =~ /^.ACTION/
        ctcp, elems[:identified] = split_idmsg(ctcp)
      end

      if ctcp !~ /^(\w+)(?: (.*))?/
        warn "Received malformed CTCP from #{elems[:prefix]}: #{ctcp}"
        return
      end
      ctcp_name, ctcp_args = $~.captures

      if ctcp_name == 'DCC'
        if ctcp_args !~ /^(\w+) +(.+)/
          warn "Received malformed DCC request from #{elems[:prefix]}: #{ctcp}"
          return
        end
        dcc_name, dcc_args = $~.captures
        elems[:args][1] = dcc_args
        elems[:dcc_type] = dcc_name

        begin
          message_class = constantize("IRCSupport::Message::DCC::" + dcc_name.capitalize)
        rescue
          message_class = constantize("IRCSupport::Message::DCC")
        end

        return message_class.new(elems)
      else
        elems[:args][1] = ctcp_args || ''

        if @isupport['CHANTYPES'].include? elems[:args][0][0]
          elems[:is_public] = true
        end

        # treat CTCP ACTIONs as normal messages with a special attribute
        if ctcp_name == 'ACTION'
          elems[:is_action] = true
          return IRCSupport::Message::Message.new(elems)
        end

        begin
          message_class = constantize("IRCSupport::Message::#{ctcp_type}_" + ctcp_name.capitalize)
        rescue
          message_class = constantize("IRCSupport::Message::#{ctcp_type}")
        end

        elems[:ctcp_type] = ctcp_name
        return message_class.new(elems)
      end
    end

    def ctcp_dequote(line)
      line = low_dequote(line)

      # filter misplaced \x01 before processing
      if line.count("\x01") % 2 != 0
        line[line.rindex("\x01")] = '\a'
      end

      return if line !~ /\x01/

      chunks = line.split(/\x01/)
      chunks.shift if chunks.first.empty?

      chunks.each do |chunk|
        # Dequote unnecessarily quoted chars, and convert escaped \'s and ^A's.
        chunk.gsub!(/\\([^\\a])/, "\\1")
        chunk.gsub!(/\\\\/, "\\")
        chunk.gsub!(/\\a/, "\x01")
      end

      ctcp, text = [], []

      # If the line begins with a control-A, the first chunk is a CTCP
      # line. Otherwise, it starts with text and alternates with CTCP
      # lines. Really stupid protocol.
      ctcp << chunks.shift if line =~ /^\x01/

      while not chunks.empty?
        text << chunks.shift
        ctcp << chunks.shift if not chunks.empty?
      end

      return ctcp, text
    end

    def low_quote(line)
      return line.sub(@@low_quote_from, @@low_quote_to)
    end

    def low_dequote(line)
      return line.sub(@@low_dequote_from, @@low_dequote_to)
    end
  end
end
