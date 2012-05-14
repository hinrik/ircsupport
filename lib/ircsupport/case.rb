module IRCSupport
  module Case
    # @private
    @@ascii_map = ['a-z', 'A-Z']
    # @private
    @@rfc1459_map = ['a-z{}^|', 'A-Z[]~\\']
    # @private
    @@strict_rfc1459_map = ['a-z{}|', 'A-Z[]\\']

    module_function

    # @param [String] irc_string An IRC string (nickname, channel, etc).
    # @param [Symbol] casemapping An IRC casemapping.
    # Like {#irc_upcase}, but modifies the string in place.
    # @return [String] An upper case version of the IRC string according to
    #   the casemapping.
    def irc_upcase!(irc_string, casemapping = :rfc1459)
      case casemapping
      when :ascii
        irc_string.tr!(*@@ascii_map)
      when :rfc1459
        irc_string.tr!(*@@rfc1459_map)
      when :'strict-rfc1459'
        # the backslash must be last, otherwise it causes issues
        irc_string.tr!(*@@strict_rfc1459_map)
      else
        raise ArgumentError, "Unsupported casemapping #{casemapping}"
      end

      return irc_string
    end

    # @param [String] irc_string An IRC string (nickname, channel, etc)
    # @param [Symbol] casemapping An IRC casemapping
    # @return [String] An upper case version of the IRC string according to
    #   the casemapping.
    def irc_upcase(irc_string, casemapping = :rfc1459)
      result = irc_string.dup
      irc_upcase!(result, casemapping)
      return result
    end

    # @param [String] irc_string An IRC string (nickname, channel, etc)
    # @param [Symbol] casemapping An IRC casemapping
    # Like {#irc_downcase}, but modifies the string in place.
    # @return [String] A lower case version of the IRC string according to
    #   the casemapping
    def irc_downcase!(irc_string, casemapping = :rfc1459)
      case casemapping
      when :ascii
        irc_string.tr!(*@@ascii_map.reverse)
      when :rfc1459
        irc_string.tr!(*@@rfc1459_map.reverse)
      when :'strict-rfc1459'
        # the backslash must be last, otherwise it causes issues
        irc_string.tr!(*@@strict_rfc1459_map.reverse)
      else
        raise ArgumentError, "Unsupported casemapping #{casemapping}"
      end

      return irc_string
    end

    # @param [String] irc_string An IRC string (nickname, channel, etc).
    # @param [Symbol] casemapping An IRC casemapping.
    # @return [String] A lower case version of the IRC string according to
    #   the casemapping
    def irc_downcase(irc_string, casemapping = :rfc1459)
      result = irc_string.dup
      irc_downcase!(result, casemapping)
      return result
    end

    # @param [String] first The first IRC string to compare.
    # @param [String] second The second IRC string to compare.
    # @param [Symbol] casemapping The IRC casemappig to use for the comparison.
    # @return [Boolean] Will be `true` if the strings only differ in case or
    #   not all, but `false` otherwise.
    def irc_eql?(first, second, casemapping = :rfc1459)
      return irc_upcase(first, casemapping) == irc_upcase(second, casemapping)
    end
  end
end
