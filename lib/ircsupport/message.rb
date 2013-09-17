require 'ircsupport/numerics'

module IRCSupport
  class Message
    # @return [String] The sender prefix of the IRC message, if any.
    attr_accessor :prefix

    # @return [String] The IRC command.
    attr_accessor :command

    # @return [Array] The arguments to the IRC command.
    attr_accessor :args

    # @private
    def initialize(line, isupport, capabilities)
      @prefix = line.prefix
      @command = line.command
      @args = line.args
    end

    # @return [Symbol] The type of the IRC message.
    def type
      # type override
      return @type if @type

      # messages without their own subclass just use the IRC command name
      return @command.downcase.to_sym if self.class.name == 'IRCSupport::Message'

      # with a subclass, base it on the class name
      type = self.class.name.match(/^IRCSupport::Message::(.*)/)[1]
      type.gsub!(/::|(?<=[[:lower:]])(?=[[:upper:]])/, '_')

      # subtype override
      if @subtype
        type.sub!(/_.*/, '')
        return "#{type}_#{@subtype}".downcase.to_sym
      else
        return type.downcase.to_sym
      end
    end

    class Numeric < Message
      # @return [String] The name of the IRC command numeric (e.g. RPL_WELCOME).
      attr_accessor :name

      # @private
      def initialize(line, isupport, capabilities)
        super
        @name = IRCSupport::Numerics.numeric_to_name(@command)
        @type = @command.to_sym
      end

      # @return [Boolean] Will be true if this is an error numeric.
      def is_error?
        return !!(@name =~ /^ERR/)
      end
    end

    class Numeric005 < Numeric
      # @private
      @@isupport_mappings = {
        %w[MODES MAXCHANNELS NICKLEN MAXBANS TOPICLEN
        KICKLEN CHANNELLEN CHIDLEN SILENCE AWAYLEN
        MAXTARGETS WATCH MONITOR] => ->(v) { v.to_i },

        %w[STATUSMSG ELIST CHANTYPES] => ->(v) { v.split("").to_set },

        %w[CASEMAPPING] => ->(v) { v.to_sym },

        %w[NETWORK] => ->(v) { v },

        %w[PREFIX] => ->(v) {
          modes, prefixes = v.match(/^\((.+)\)(.+)$/)[1..2]
          h = {}
          modes.split("").each_with_index do |c, i|
            h[c] = prefixes[i]
          end
          h
        },

        %w[CHANMODES] => ->(v) {
          h = {}
          h["A"], h["B"], h["C"], h["D"] = v.split(",").map {|l| l.split("").to_set }
          h
        },

        %w[CHANLIMIT MAXLIST IDCHAN] => ->(v) {
          h = {}
          v.split(",").each do |pair|
            args, num = pair.split(":")
            args.split("").each do |arg|
              h[arg] = num.to_i
            end
          end
          h
        },

        %w[TARGMAX] => ->(v) {
          h = {}
          v.split(",").each do |pair|
            name, value = pair.split(":")
            h[name] = value.to_i
          end
          h
        },
      }

      # @return [Hash] The isupport options contained in the command.
      attr_accessor :isupport

      # @private
      def initialize(line, isupport, capabilities)
        super
        @isupport = {}
        @args.each do |value|
          name, value = value.split(/=/, 2)
          if value
            proc = @@isupport_mappings.find {|key, _| key.include?(name)}
            @isupport[name] = (proc && proc[1].call(value)) || value
          else
            @isupport[name] = true
          end
        end
      end
    end

    class Numeric353 < Numeric
      # @return [String] The channel.
      attr_accessor :channel

      # @return [String] The channel type.
      attr_accessor :channel_type

      # @return [Hash] The key is a username, the value is an array of that
      #   user's prefixes.
      attr_accessor :users

      # @private
      def initialize(line, isupport, capabilities)
        super
        data = @args.last(@args.size - 1)
        @channel_type = data.shift if data[0] =~ /^[@=*]$/
        @channel = data[0]
        @users = {}
        prefixes = isupport["PREFIX"].values.map { |p| Regexp.quote p }

        data[1].split(/\s+/).each do |user|
          user.sub! /^((?:#{prefixes.join '|'})*)/, ''
          @users[user] = $1.split(//)
        end
      end
    end

    class Numeric352 < Numeric
      # @return [String] The target of the who reply, either a nickname or
      #   a channel name.
      attr_accessor :target

      # @return [String] The username.
      attr_accessor :username

      # @return [String] The host name.
      attr_accessor :hostname

      # @return [String] The server name.
      attr_accessor :server

      # @return [String] The nickname.
      attr_accessor :nickname

      # @return [Array] The user's prefixes.
      attr_accessor :prefixes

      # @return [Boolean] The away status.
      attr_accessor :away

      # @return [Fixnum] The user's hop count.
      attr_accessor :hops

      # @return [String] The user's realname.
      attr_accessor :realname

      # @private
      def initialize(line, isupport, capabilities)
        super
        @target, @username, @hostname, @server, @nickname, status, rest =
          @args.last(@args.size - 1)
        status.sub! /[GH]/, ''
        @away = $1 == 'G' ? true : false
        @prefixes = status.split ''
        @hops, @realname = rest.split /\s/, 2
        @hops = @hops.to_i
      end
    end

    class DCC < Message
      # @return [String] The sender of the DCC message.
      attr_accessor :sender

      # @return [Symbol] The type of the DCC message.
      attr_accessor :dcc_type

      # @return [String] The argument string to the DCC message.
      attr_accessor :dcc_args

      # @private
      def initialize(line, isupport, capabilities, dcc_type)
        super(line, isupport, capabilities)
        @sender = @prefix
        @dcc_args = @args[1]
        @dcc_type = dcc_type.downcase.to_sym
        @subtype = @dcc_type
      end
    end

    class DCC::Chat < DCC
      # @return [IPAddr] The sender's IP address.
      attr_accessor :address

      # @return [Fixnum] The sender's port number.
      attr_accessor :port

      # @private
      def initialize(line, isupport, capabilities, dcc_type)
        super
        return if @dcc_args !~ /^(?:".+"|[^ ]+) +(\S+) +(\d+)/
        @address, @port = $1, $2.to_i
        if @address =~ /^\d+$/
          @address = [24, 16, 8, 0].collect {|b| (@address.to_i >> b) & 255}.join('.')
        end
      end
    end

    class DCC::Send < DCC
      # @return [IPAddr] The sender's IP address.
      attr_accessor :address

      # @return [Fixnum] The sender's port number.
      attr_accessor :port

      # @return [String] The source filename.
      attr_accessor :filename

      # @return [Fixnum] The size of the source file, in bytes.
      attr_accessor :size

      # @private
      def initialize(line, isupport, capabilities, dcc_type)
        super
        return if @dcc_args !~ /^(".+"|[^ ]+) +(\S+) +(\d+)(?: +(\d+))?/
        @filename = $1
        @address = $2
        @port = $3.to_i
        @size = $4.to_i

        if @filename =~ /^"/
          @filename.gsub!(/^"|"$/, '')
          @filename.gsub!(/\\\\/, '\\');
          @filename.gsub!(/\\"/, '"');
        end

        if @address =~ /^\d+$/
          @address = [24, 16, 8, 0].collect {|b| (@address.to_i >> b) & 255}.join('.')
        end
      end
    end

    class DCC::Accept < DCC
      # @return [String] The source filename.
      attr_accessor :filename

      # @return [Fixnum] The sender's port number.
      attr_accessor :port

      # @return [Fixnum] The byte position in the file.
      attr_accessor :position

      # @private
      def initialize(line, isupport, capabilities, dcc_type)
        super
        return if @dcc_args !~ /^(".+"|[^ ]+) +(\d+) +(\d+)/
        @filename = $1
        @port = $2.to_i
        @position = $3.to_i

        if @filename =~ /^"/
          @filename.gsub!(/^"|"$/, '')
          @filename.gsub!(/\\\\/, '\\');
          @filename.gsub!(/\\"/, '"');
        end
      end
    end

    class DCC::Resume < DCC::Accept; end

    class Error < Message
      # @return [String] The error message.
      attr_accessor :error

      # @private
      def initialize(line, isupport, capabilities)
        super
        @error = @args[0]
      end
    end

    class Invite < Message
      # @return [String] The user who sent the invite.
      attr_accessor :inviter

      # @return [String] The name of the channel you're being invited to.
      attr_accessor :channel

      # @private
      def initialize(line, isupport, capabilities)
        super
        @inviter = @prefix
        @channel = @args[1]
      end
    end

    class Join < Message
      # @return [String] The user who is joining.
      attr_accessor :joiner

      # @return [String] The name of the channel being joined.
      attr_accessor :channel

      # @private
      def initialize(line, isupport, capabilities)
        super
        @joiner = @prefix
        @channel = @args[0]

        if capabilities.include?('extended-join')
          @account = @args[1] if @args[1] != '*'
          @realname = @args[2]
          def self.account; @account; end
          def self.account=(account); @account = account; end
          def self.realname; @realname; end
          def self.realname=(realname); @realname = realname; end
        end
      end
    end

    class Part < Message
      # @return [String] The user who is parting.
      attr_accessor :parter

      # @return [String] The name of the channel being parted.
      attr_accessor :channel

      # @return [String] The part message, if any.
      attr_accessor :message

      # @private
      def initialize(line, isupport, capabilities)
        super
        @parter = @prefix
        @channel = @args[0]
        @message = @args[1]
        @message = nil if @message && @message.empty?
      end
    end

    class Kick < Message
      # @return [String] The user who is doing the kicking.
      attr_accessor :kicker

      # @return [String] The name of the channel.
      attr_accessor :channel

      # @return [String] The user being kicked.
      attr_accessor :kickee

      # @return [String] The kick message, if any.
      attr_accessor :message

      # @private
      def initialize(line, isupport, capabilities)
        super
        @kicker = @prefix
        @channel = @args[0]
        @kickee = @args[1]
        @message = @args[2]
        @message = nil if @message && @message.empty?
      end
    end

    class UserModeChange < Message
      # @return [Array] The mode changes as returned by
      #   {IRCSupport::Modes#parse_modes}.
      attr_accessor :mode_changes

      # @private
      def initialize(line, isupport, capabilities)
        super
        @mode_changes = IRCSupport::Modes.parse_modes(@args[0])
      end
    end

    class ChannelModeChange < Message
      # @return [String] The user or server doing the mode change(s).
      attr_accessor :changer

      # @return [String] The channel name.
      attr_accessor :channel

      # @return [Array] The mode changes as returned by
      #   {IRCSupport::Modes#parse_modes}.
      attr_accessor :mode_changes

      # @private
      def initialize(line, isupport, capabilities)
        super
        @changer = @prefix
        @channel = @args[0]
        @mode_changes = IRCSupport::Modes.parse_channel_modes(
          @args.last(@args.size - 1),
          chanmodes: isupport["CHANMODES"],
          statmodes: isupport["PREFIX"].keys,
        )
      end
    end

    class Nick < Message
      # @return [String] The user who is changing their nick.
      attr_accessor :changer

      # @return [String] The new nickname.
      attr_accessor :nickname

      # @private
      def initialize(line, isupport, capabilities)
        super
        @changer = @prefix
        @nickname = @args[0]
      end
    end

    class Topic < Message
      # @return [String] The user or server which is changing the topic.
      attr_accessor :changer

      # @return [String] The name of the channel.
      attr_accessor :channel

      # @return [String] The new topic.
      attr_accessor :topic

      # @private
      def initialize(line, isupport, capabilities)
        super
        @changer = @prefix
        @channel = @args[0]
        @topic = @args[1]
        @topic = nil if @topic && @topic.empty?
      end
    end

    class Quit < Message
      # @return [String] The user who is quitting.
      attr_accessor :quitter

      # @return [String] The quit message, if any.
      attr_accessor :message

      # @private
      def initialize(line, isupport, capabilities)
        super
        @quitter = @prefix
        @message = @args[0]
        @message = nil if @message && @message.empty?
      end
    end

    class Ping < Message
      # @return [String] The ping message, if any.
      attr_accessor :message

      # @private
      def initialize(line, isupport, capabilities)
        super
        @message = @args[0]
        @message = nil if @message && @message.empty?
      end
    end

    class CAP < Message
      # @return [String] The CAP subcommand.
      attr_accessor :subcommand

      # @return [Boolean] Will be true if this is a multipart reply.
      attr_accessor :multipart

      # @return [String] The text of the CAP reply.
      attr_accessor :reply

      # @private
      def initialize(line, isupport, capabilities)
        super
        @subcommand = @args[0]
        @subtype = @subcommand
        if @args[1] == '*'
          @multipart = true
          @reply = @args[2]
        else
          @multipart = false
          @reply = @args[1]
        end
      end
    end

    class CAP::LS < CAP
      # @return [Hash] The capabilities referenced in the CAP reply. The keys
      #   are the capability names, and the values are arrays of modifiers
      #   (`:enable`, `:disable`, `:sticky`).
      attr_accessor :capabilities

      # @private
      @@modifiers = {
        '-' => :disable,
        '~' => :enable,
        '=' => :sticky,
      }

      # @private
      def initialize(line, isupport, capabilities)
        super
        @capabilities = {}

        reply.split.each do |chunk|
          mods, capability = chunk.match(/\A([-=~]*)(.*)/).captures
          modifiers = []
          mods.split('').each do |modifier|
            modifiers << @@modifiers[modifier] if @@modifiers[modifier]
          end
          modifiers << :enable if mods.empty?
          @capabilities[capability] = modifiers
        end
      end
    end

    class CAP::LIST < CAP::LS; end
    class CAP::ACK < CAP::LS; end

    class ServerNotice < Message
      # @return [String] The sender of the notice. Could be a server name,
      #   a service, or nothing at all.
      attr_accessor :sender

      # @return [String] The target of the server notice. Could be '*' or
      #   'AUTH' or something else entirely.
      attr_accessor :target

      # @return [String] The text of the notice.
      attr_accessor :message

      # @private
      def initialize(line, isupport, capabilities)
        super
        @sender = @prefix

        if @args.size == 2
          @target = @args[0]
          @message = @args[1]
        else
          @message = @args[0]
        end
      end
    end

    class Privmsg < Message
      # @return [String] The user who sent the message.
      attr_accessor :sender

      # @return [String] The text of the message.
      attr_accessor :message

      # @return [String] The name of the channel this message was sent to,
      #   if any.
      attr_accessor :channel

      # @private
      def initialize(line, isupport, capabilities)
        super
        @sender = @prefix
        @message = @args[1]

        if isupport['CHANTYPES'].include?(@args[0][0])
          # broadcast messages are so 90s
          @channel = @args[0].split(/,/).first
        end

        if capabilities.include?('identify-msg')
          @identified, @message = @message.split(//, 2)
          @identified = @identified == '+' ? true : false
          def self.identified?; !!@identified; end
        end
      end
    end

    class Notice < Privmsg; end

    class CTCP < Message
      # @return [String] The user who sent the message.
      attr_accessor :sender

      # @return [String] The name of the channel this message was sent to,
      #   if any.
      attr_accessor :channel

      # @return [Symbol] The type of the CTCP message.
      attr_accessor :ctcp_type

      # @return [String] The arguments to the CTCP.
      attr_accessor :ctcp_args

      # @private
      def initialize(line, isupport, capabilities, ctcp_type)
        super(line, isupport, capabilities)
        @sender = @prefix
        @ctcp_args = @args[1]
        @ctcp_type = ctcp_type.downcase.to_sym
        @subtype = @ctcp_type

        if isupport['CHANTYPES'].include?(@args[0][0])
          # broadcast messages are so 90s
          @channel = @args[0].split(/,/).first
        end
      end
    end

    class CTCPReply < CTCP; end

    class CTCP::Action < CTCP
      # @return [String] The text of the message.
      attr_accessor :message

      def initialize(line, isupport, capabilities, ctcp_type)
        super
        @message = @args[1]

        if capabilities.include?('identify-msg')
          @identified, @message = @message.split(//, 2)
          @identified = @identified == '+' ? true : false
          def self.identified?; !!@identified; end
        end
      end
    end
  end
end
