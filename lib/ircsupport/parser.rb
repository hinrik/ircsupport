require 'ircsupport/message'

module IRCSupport
  Line = Struct.new(:prefix, :command, :args)

  class Parser
    # @private
    @@illegal     = '\x00\x0a\x0d'
    # @private
    @@eol         = /\x0d?\x0a/
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
    @@irc_name    = /[^#@@illegal :][^#@@illegal ]*/
    # @private
    @@irc_line    = /
      \A
      (?: : (?<prefix> #@@non_space ) #@@space )?
      (?<command> #@@numeric | #@@command )
      (?: #@@space (?<args> #@@irc_name (?: #@@space #@@irc_name )* ) )?
      (?: #@@space : (?<trailing_arg> [^#@@illegal]* ) | #@@maybe_space )?
      #@@eol?
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
      "CHANTYPES" => %w[#].to_set,
      "CHANMODES" => {
        "A" => %w[b].to_set,
        "B" => %w[k].to_set,
        "C" => %w[l].to_set,
        "D" => %w[i m n p s t r].to_set,
      },
      "MODES"       => 1,
      "NICKLEN"     => Float::INFINITY,
      "MAXBANS"     => Float::INFINITY,
      "TOPICLEN"    => Float::INFINITY,
      "KICKLEN"     => Float::INFINITY,
      "CHANNELLEN"  => Float::INFINITY,
      "CHIDLEN"     => 5,
      "AWAYLEN"     => Float::INFINITY,
      "MAXTARGETS"  => 1,
      "MAXCHANNELS" => Float::INFINITY,
      "CHANLIMIT"   => {"#" => Float::INFINITY},
      "STATUSMSG"   => %w[@ +].to_set,
      "CASEMAPPING" => :rfc1459,
      "ELIST"       => Set.new,
      "MONITOR"     => 0,
    }

    # The isupport configuration of the IRC server.
    # The configuration will be seeded with sane defaults, and updated in
    # response to parsed {IRCSupport::Message::Numeric005 `005`} messages.
    # @return [Hash]
    attr_reader :isupport

    # A list of currently enabled capabilities.
    # It will be updated in response to parsed {IRCSupport::Message::CAP::ACK `CAP ACK`} messages.
    # @return [Set]
    attr_reader :capabilities

    # @private
    def initialize
      @isupport = @@default_isupport
      @capabilities = Set.new
    end

    # Perform low-level parsing of an IRC protocol line.
    # @param [String] raw_line An IRC protocol line you wish to decompose.
    # @return [IRCSupport::Line] An IRC protocol line object.
    def decompose(raw_line)
      if raw_line =~ @@irc_line
        c = $~
        line = IRCSupport::Line.new
        line.prefix = c[:prefix] if c[:prefix]
        line.command = c[:command].upcase
        line.args = []
        line.args.concat c[:args].split(@@space) if c[:args]
        line.args << c[:trailing_arg] if c[:trailing_arg]
      else
        raise ArgumentError, "Line is not IRC protocol: #{raw_line.inspect}"
      end

      return line
    end

    # Compose an IRC protocol line.
    # @param [IRCSupport::Line] line An IRC protocol line object
    #   (as returned by {#decompose}).
    # @return [String] An IRC protocol line.
    def compose(line)
      raise ArgumentError, "You must specify a command" if !line.command
      raw_line = ''
      raw_line << ":#{line.prefix} " if line.prefix
      raw_line << line.command

      if line.args
        line.args.each_with_index do |arg, idx|
          raw_line << ' '
          if idx != line.args.count-1 and arg.match(@@space)
            raise ArgumentError, "Only the last argument may contain spaces"
          end
          if idx == line.args.count-1
            raw_line << ':' if arg.match(@@space)
          end
          raw_line << arg
        end
      end

      return raw_line
    end

    # Parse an IRC protocol line into a complete message object.
    # @param [String] raw_line An IRC protocol line.
    # @return [IRCSupport::Message] A parsed message object.
    def parse(raw_line)
      line = decompose(raw_line)

      if line.command =~ /^(PRIVMSG|NOTICE)$/ && line.args[1] =~ /\x01/
        return handle_ctcp_message(line)
      end

      msg_class = case
      when line.command =~ /^\d{3}$/
        begin
          constantize("IRCSupport::Message::Numeric#{line.command}")
        rescue
          constantize("IRCSupport::Message::Numeric")
        end
      when line.command == "MODE"
        if @isupport['CHANTYPES'].include?(line.args[0][0])
          constantize("IRCSupport::Message::ChannelModeChange")
        else
          constantize("IRCSupport::Message::UserModeChange")
        end
      when line.command == "NOTICE" && (!line.prefix || line.prefix !~ /!/)
        constantize("IRCSupport::Message::ServerNotice")
      when line.command == "CAP" && %w{LS LIST ACK}.include?(line.args[0])
        constantize("IRCSupport::Message::CAP::#{line.args[0]}")
      else
        begin
          constantize("IRCSupport::Message::#{line.command.capitalize}")
        rescue
          constantize("IRCSupport::Message")
        end
      end

      message = msg_class.new(line, @isupport, @capabilities)

      case message.type
      when :'005'
        @isupport.merge! message.isupport
      when :cap_ack
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

    def handle_ctcp_message(line)
      ctcp_type = line.command == 'PRIVMSG' ? 'CTCP' : 'CTCPReply'
      ctcps, texts = ctcp_dequote(line.args[1])

      # We only process the first CTCP, ignoring extra CTCPs and any
      # non-CTCPs. Those who send anything in addition to that first CTCP
      # are probably up to no good (e.g. trying to flood a bot by having it
      # reply to 20 CTCP VERSIONs at a time).
      line.args[1] = ctcps.first

      rx = @capabilities.include?('identify-msg') ? /(?<=^.)ACTION / : /^ACTION /
      if line.args[1].sub!(rx, '')
        return IRCSupport::Message::CTCP::Action.new(line, @isupport, @capabilities)
      end

      if line.args[1] !~ /^(\w+)(?: (.*))?/
        warn "Received malformed CTCP from #{line.prefix}: #{line.args[1]}"
        return
      end
      ctcp_name, ctcp_args = $~.captures

      if ctcp_name == 'DCC'
        if ctcp_args !~ /^(\w+) +(.+)/
          warn "Received malformed DCC request from #{line.prefix}: #{line.args[1]}"
          return
        end
        dcc_name, dcc_args = $~.captures
        line.args[1] = dcc_args

        message_class = begin
          constantize("IRCSupport::Message::DCC::" + dcc_name.capitalize)
        rescue
          constantize("IRCSupport::Message::DCC")
        end

        return message_class.new(line, @isupport, @capabilities, dcc_name)
      else
        line.args[1] = ctcp_args || ''

        message_class = begin
          constantize("IRCSupport::Message::#{ctcp_type}_" + ctcp_name.capitalize)
        rescue
          constantize("IRCSupport::Message::#{ctcp_type}")
        end

        return message_class.new(line, @isupport, @capabilities, ctcp_name)
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
