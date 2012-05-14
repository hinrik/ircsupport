module IRCSupport
  module Validations
    # @private
    @@nickname = /
      \A
      [A-Za-z_`\-^\|\\\{}\[\]]
      [A-Za-z_0-9`\-^\|\\\{}\[\]]*
      \z
    /x
    # @private
    @@channel = /[^\x00\x07\x0a\x0d :,]+/

    module_function

    # @param [String] nickname A nickname to validate.
    # @return [Boolean] Will be true if the nickname is valid.
    def valid_nickname?(nickname)
      return true if nickname =~ @@nickname
      return false
    end

    # @param [String] channel A channel name to validate.
    # @param [Array] chantypes The channel types which are allowed. This is
    #   the same as the "CHANTYPES" isupport option.
    # @return [Boolean] Will be true if the channel name is valid.
    def valid_channel_name?(channel, chantypes = ['#', '&'])
      prefix = Regexp.quote(chantypes.join)
      return false if channel.bytesize > 200
      return true if channel =~ /\A[#{prefix}]#@@channel\z/
      return false
    end
  end
end
