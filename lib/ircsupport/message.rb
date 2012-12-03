require 'ircsupport/numerics'
require 'ipaddr'
require 'pathname'

module IRCSupport
  class Message
    # @return [String] The sender prefix of the IRC message, if any.
    attr_accessor :prefix

    # @return [String] The IRC command.
    attr_accessor :command

    # @return [Array] The arguments to the IRC command.
    attr_accessor :args

    # @private
    def initialize(args)
      @prefix = args[:prefix]
      @command = args[:command]
      @args = args[:args]
    end

    # @return [String] The type of the IRC message.
    def type
      return @type if @type
      return @command.downcase.to_sym if self.class.name == 'IRCSupport::Message'
      type = self.class.name.match(/^IRCSupport::Message::(.*)/)[1]
      return type.gsub(/::|(?<=[[:lower:]])(?=[[:upper:]])/, '_').downcase.to_sym
    end

    class Numeric < Message
      # @return [String] The IRC command numeric.
      attr_accessor :numeric

      # @return [String] The name of the IRC command numeric.
      attr_accessor :numeric_name

      # @return [String] The arguments to the numeric command.
      attr_accessor :numeric_args

      # @private
      def initialize(args)
        super(args)
        @numeric = args[:command]
        @numeric_args = args[:args]
        @numeric_name = IRCSupport::Numerics.numeric_to_name(@numeric)
        @type = @numeric.to_sym
      end

      # @return [Boolean] Will be true if this is an error numeric.
      def is_error?
        return @numeric_name =~ /^ERR/ ? true : false
      end
    end

    class Numeric005 < Numeric
      # @private
      @@isupport_mappings = {
        %w[MODES MAXCHANNELS NICKLEN MAXBANS TOPICLEN
        KICKLEN CHANNELLEN CHIDLEN SILENCE AWAYLEN
        MAXTARGETS WATCH MONITOR] => ->(v) { v.to_i },

        %w[STATUSMSG ELIST CHANTYPES] => ->(v) { v.split("") },

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
          h["A"], h["B"], h["C"], h["D"] = v.split(",").map {|l| l.split("")}
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
      def initialize(args)
        super(args)
        @isupport = {}
        args[:args].each do |value|
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

      # @return [Array] Each element is an array of two elements: the user
      #   prefix (if any), and the name of the user.
      attr_accessor :users

      # @private
      def initialize(args)
        super(args)
        data = @args.last(@args.size - 1)
        @channel_type = data.shift if data[0] =~ /^[@=*]$/
        @channel = data[0]
        @users = []
        prefixes = args[:isupport]["PREFIX"].values.map { |p| Regexp.quote p }

        data[1].split(/\s+/).each do |user|
          user.sub! /^(#{prefixes.join '|'})/, ''
          @users.push [$1, user]
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
      def initialize(args)
        super(args)
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
      def initialize(args)
        super(args)
        @sender = args[:prefix]
        @dcc_args = args[:args][1]
        @dcc_type = args[:dcc_type].downcase.to_sym
        @type = "dcc_#@dcc_type".to_sym
      end
    end

    class DCC::Chat < DCC
      # @return [IPAddr] The sender's IP address.
      attr_accessor :address

      # @return [Fixnum] The sender's port number.
      attr_accessor :port

      # @private
      def initialize(args)
        super(args)
        return if @dcc_args !~ /^(?:".+"|[^ ]+) +(\d+) +(\d+)/
        @address = IPAddr.new($1.to_i, Socket::AF_INET)
        @port = $2.to_i
      end
    end

    class DCC::Send < DCC
      # @return [IPAddr] The sender's IP address.
      attr_accessor :address

      # @return [Fixnum] The sender's port number.
      attr_accessor :port

      # @return [Pathname] The source filename.
      attr_accessor :filename

      # @return [Fixnum] The size of the source file, in bytes.
      attr_accessor :size

      # @private
      def initialize(args)
        super(args)
        return if @dcc_args !~ /^(".+"|[^ ]+) +(\d+) +(\d+)(?: +(\d+))?/
        @filename = $1
        @address = IPAddr.new($2.to_i, Socket::AF_INET)
        @port = $3.to_i
        @size = $4.to_i

        if @filename =~ /^"/
          @filename.gsub!(/^"|"$/, '')
          @filename.gsub!(/\\"/, '"');
        end

        @filename = Pathname.new(@filename).basename
      end
    end

    class DCC::Accept < DCC
      # @return [Pathname] The source filename.
      attr_accessor :filename

      # @return [Fixnum] The sender's port number.
      attr_accessor :port

      # @return [Fixnum] The byte position in the file.
      attr_accessor :position

      # @private
      def initialize(args)
        super(args)
        return if @dcc_args !~ /^(".+"|[^ ]+) +(\d+) +(\d+)/
        @filename = $1
        @port = $2.to_i
        @position = $3.to_i

        if @filename =~ /^"/
          @filename.gsub!(/^"|"$/, '')
          @filename.gsub!(/\\"/, '"');
        end

        @filename = Pathname.new(@filename).basename
      end
    end

    class DCC::Resume < DCC::Accept; end

    class Error < Message
      # @return [String] The error message.
      attr_accessor :error

      # @private
      def initialize(args)
        super(args)
        @error = args[:args][0]
      end
    end

    class Invite < Message
      # @return [String] The user who sent the invite.
      attr_accessor :inviter

      # @return [String] The name of the channel you're being invited to.
      attr_accessor :channel

      # @private
      def initialize(args)
        super(args)
        @inviter = args[:prefix]
        @channel = args[:args][1]
      end
    end

    class Join < Message
      # @return [String] The user who is joining.
      attr_accessor :joiner

      # @return [String] The name of the channel being joined.
      attr_accessor :channel

      # @private
      def initialize(args)
        super(args)
        @joiner = args[:prefix]
        @channel = args[:args][0]
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
      def initialize(args)
        super(args)
        @parter = args[:prefix]
        @channel = args[:args][0]
        @message = args[:args][1]
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
      def initialize(args)
        super(args)
        @kicker = args[:prefix]
        @channel = args[:args][0]
        @kickee = args[:args][1]
        @message = args[:args][2]
        @message = nil if @message && @message.empty?
      end
    end

    class UserModeChange < Message
      # @return [Array] The mode changes as returned by
      #   {IRCSupport::Modes#parse_modes}.
      attr_accessor :mode_changes

      # @private
      def initialize(args)
        super(args)
        @mode_changes = IRCSupport::Modes.parse_modes(args[:args][0])
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
      def initialize(args)
        super(args)
        @changer = args[:prefix]
        @channel = args[:args][0]
        @mode_changes = IRCSupport::Modes.parse_channel_modes(
          args[:args].last(args[:args].size - 1),
          chanmodes: args[:isupport]["CHANMODES"],
          statmodes: args[:isupport]["PREFIX"].keys,
        )
      end
    end

    class Nick < Message
      # @return [String] The user who is changing their nick.
      attr_accessor :changer

      # @return [String] The new nickname.
      attr_accessor :nickname

      # @private
      def initialize(args)
        super(args)
        @changer = args[:prefix]
        @nickname = args[:args][0]
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
      def initialize(args)
        super(args)
        @changer = args[:prefix]
        @channel = args[:args][0]
        @topic = args[:args][1]
        @topic = nil if @topic && @topic.empty?
      end
    end

    class Quit < Message
      # @return [String] The user who is quitting.
      attr_accessor :quitter

      # @return [String] The quit message, if any.
      attr_accessor :message

      # @private
      def initialize(args)
        super(args)
        @quitter = args[:prefix]
        @message = args[:args][0]
        @message = nil if @message && @message.empty?
      end
    end

    class Ping < Message
      # @return [String] The ping message, if any.
      attr_accessor :message

      # @private
      def initialize(args)
        super(args)
        @message = args[:args][0]
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
      def initialize(args)
        super(args)
        @subcommand = args[:args][0]
        @type = "cap_#{@subcommand.downcase}".to_sym
        if args[:args][1] == '*'
          @multipart = true
          @reply = args[:args][2]
        else
          @multipart = false
          @reply = args[:args][1]
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
      def initialize(args)
        super(args)
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
      # a service, or nothing at all.
      attr_accessor :sender

      # @return [String] The target of the server notice. Could be '*' or
      # 'AUTH' or something else entirely.
      attr_accessor :target

      # @return [String] The text of the notice.
      attr_accessor :message

      # @private
      def initialize(args)
        super(args)
        @sender = args[:prefix]
        if args[:args].size == 2
          @target = args[:args][0]
          @message = args[:args][1]
        else
          @message = args[:args][0]
        end
      end
    end

    class Message < Message
      # @return [String] The user who sent the message.
      attr_accessor :sender

      # @return [String] The text of the message.
      attr_accessor :message

      # @return [String] The name of the channel this message was sent to,
      #   if any.
      attr_accessor :channel

      # @private
      def initialize(args)
        super(args)
        @sender = args[:prefix]
        @message = args[:args][1]
        @is_action = args[:is_action] || false
        @is_notice = args[:is_notice] || false

        if args[:is_public]
          # broadcast messages are so 90s
          @channel = args[:args][0].split(/,/).first
        end

        if args[:capabilities].include?('identify-msg')
          @identified = args[:identified]
          def self.identified?; @identified; end
        end
      end

      # @return [Boolean] Will be true if this message is an action.
      def is_action?; @is_action; end

      # @return [Boolean] Will be true if this message is a notice.
      def is_notice?; @is_notice; end
    end

    class CTCP < Message
      # @return [String] The type of the CTCP message.
      attr_accessor :ctcp_type

      # @return [String] The arguments to the CTCP.
      attr_accessor :ctcp_args

      # @private
      def initialize(args)
        super(args)
        @sender = args[:prefix]
        @ctcp_args = args[:args][1]
        @ctcp_type = args[:ctcp_type].downcase.to_sym
        @type = "ctcp_#@ctcp_type".to_sym

        if args[:is_public]
          @channel = args[:args][0].split(/,/).first
        end
      end
    end

    class CTCPReply < CTCP
      # @private
      def initialize(args)
        super(args)
        @type = "ctcpreply_#@ctcp_type".to_sym
      end
    end
  end
end
