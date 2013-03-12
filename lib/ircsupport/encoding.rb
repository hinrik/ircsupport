module IRCSupport
  module Encoding
    module_function

    # Decode a message from an IRC connection.
    # @param [String] string The IRC string you want to decode.
    # @param [Symbol] encoding The source encoding.
    # @return [String] A UTF-8 Ruby string.
    def decode_irc(string, encoding = :irc)
      string = string.dup
      decode_irc!(string, encoding)
    end

    # Encode a message to be sent over an IRC connection.
    # @param [String] string The string you want to encode.
    # @param [Symbol] encoding The target encoding.
    # @return [String] A string encoded in the encoding you specified.
    def encode_irc(string, encoding = :irc)
      string = string.dup
      encode_irc!(string, encoding)
    end

    # Decode a message from an IRC connection, modifying it in place.
    # @param [String] string The IRC string you want to decode.
    # @param [Symbol] encoding The source encoding.
    # @return [String] A UTF-8 Ruby string.
    def decode_irc!(string, encoding = :irc)
      if encoding == :irc
        # If incoming text is valid UTF-8, it will be interpreted as
        # such. If it fails validation, a CP1252 -> UTF-8 conversion
        # is performed. This allows you to see non-ASCII from mIRC
        # users (non-UTF-8) and other users sending you UTF-8.
        #
        # (from http://xchat.org/encoding/#hybrid)
        string.force_encoding("UTF-8")
        if !string.valid_encoding?
          string.force_encoding("CP1252").encode!("UTF-8", {:invalid => :replace, :undef => :replace})
        end
      else
        string.force_encoding(encoding).encode!({:invalid => :replace, :undef => :replace})
        string = string.chars.select { |c| c.valid_encoding? }.join
      end

      return string
    end

    # Encode a message to be sent over an IRC connection, modifying it in place.
    # @param [String] string The string you want to encode.
    # @param [Symbol] encoding The target encoding.
    # @return [String] A string encoded in the encoding you specified.
    def encode_irc!(string, encoding = :irc)
      if encoding == :irc
        # If your text contains only characters that fit inside the CP1252
        # code page (aka Windows Latin-1), the entire line will be sent
        # that way. mIRC users should see it correctly. XChat users who
        # are using UTF-8 will also see it correctly, because it will fail
        # UTF-8 validation and will be assumed to be CP1252, even by older
        # XChat versions.
        #
        # If the text doesn't fit inside the CP1252 code page, (for example if you
        # type Eastern European characters, or Russian) it will be sent as UTF-8. Only
        # UTF-8 capable clients will be able to see these characters correctly
        #
        # (from http://xchat.org/encoding/#hybrid)
        begin
          string.encode!("CP1252")
        rescue ::Encoding::UndefinedConversionError
        end
      else
        string.encode!(encoding, {:invalid => :replace, :undef => :replace}).force_encoding("ASCII-8BIT")
      end

      return string
    end
  end
end
