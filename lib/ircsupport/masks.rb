require 'ircsupport/case'

module IRCSupport
  module Masks
    # @private
    @@mask_wildcard = '[\x01-\xFF]{0,}'
    # @private
    @@mask_optional = '[\x01-\xFF]{1,1}'

    module_function

    # Match strings to an IRC mask.
    # @param [String] mask The mask to match against.
    # @param [String] string The string to match against the mask.
    # @param [Symbol] casemapping The IRC casemapping to use in the match.
    # @return [Boolean] Will be true of the string matches the mask.
    def matches_mask(mask, string, casemapping = :rfc1459)
      if mask =~ /\$/
        raise ArgumentError, "Extended bans are not supported"
      end
      string = IRCSupport::Case.irc_upcase(string, casemapping)
      mask = Regexp.quote(irc_upcase(mask, casemapping))
      mask.gsub!('\*', @@mask_wildcard)
      mask.gsub!('\?', @@mask_optional)
      mask = Regexp.new(mask, nil, 'n')
      return true if string =~ /\A#{mask}\z/
      return false
    end

    # Match strings to multiple IRC masks.
    # @param [Array] mask The masks to match against.
    # @param [Array] strings The strings to match against the masks.
    # @param [Symbol] casemapping The IRC casemapping to use in the match.
    # @return [Hash] Each mask that was matched will be present as a key,
    #   and the values will be arrays of the strings that matched.
    def matches_mask_array(masks, strings, casemapping = :rfc1459)
      results = {}
      masks.each do |mask|
        strings.each do |string|
          if matches_mask(mask, string, casemapping)
            results[mask] ||= []
            results[mask] << string
          end
        end
      end
      return results
    end

    # Normalize (expand) an IRC mask.
    # @param [String] mask A partial mask (e.g. 'foo*').
    # @return [String] A normalized mask (e.g. 'foo*!*@*).
    def normalize_mask(mask)
      mask = mask.dup
      mask.gsub!(/\*{2,}/, '*')
      parts = []
      remainder = nil

      if mask !~ /!/ && mask =~ /@/
        remainder = mask
        parts[0] = '*'
      else
        parts[0], remainder = mask.split(/!/, 2)
      end

      if remainder
        remainder.gsub!(/!/, '')
        parts[1..2] = remainder.split(/@/, 2)
      end
      parts[2].gsub!(/@/, '') if parts[2]

      (1..2).each { |i| parts[i] ||= '*' }
      return parts[0] + "!" + parts[1] + "@" + parts[2]
    end
  end
end
