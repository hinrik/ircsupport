module IRCSupport
  module Formatting
    # @private
    @@color        = /[\x03\x04\x1b]/
    # @private
    @@formatting   = /[\x02\x06\x11\x16\x1d\x1f]/
    # @private
    @@mirc_color   = / \x03 (?: ,\d{1,2} | \d{1,2} (?: ,\d{1,2})? )? /x
    # @private
    @@rgb_color    = /\x04[0-9a-fA-F]{0,6}/
    # @private
    @@ecma48_color = /\x1b\[.*?[\x00-\x1f\x40-\x7e]/
    # @private
    @@normal       = /\x0f/

    # @private
    @@attributes = {
      reset:      15.chr,
      bold:       2.chr,
      underline:  31.chr,
      underlined: 31.chr,
      inverse:    22.chr,
      reverse:    22.chr,
      reversed:   22.chr,
      italic:     29.chr,
      fixed:      17.chr,
      blink:      6.chr,
    }

    # @private
    @@colors = {
      white:  "00",
      black:  "01",
      blue:   "02",
      green:  "03",
      red:    "04",
      brown:  "05",
      purple: "06",
      orange: "07",
      yellow: "08",
      lime:   "09",
      teal:   "10",
      aqua:   "11",
      royal:  "12",
      pink:   "13",
      grey:   "14",
      silver: "15",
    }

    module_function

    # Check if string has IRC color codes.
    # @param [String] string The string you want to check.
    # @return [Boolean] Will be true if the string contains IRC color codes.
    def has_color?(string)
      return true if string =~ @@color
      return false
    end

    # Check if string has IRC formatting codes.
    # @param [String] string The string you want to check.
    # @return [Boolean] Will be true if the string contains IRC formatting codes.
    def has_formatting?(string)
      return true if string =~ @@formatting
      return false
    end

    # Strip IRC color codes from a string, modifying it in place.
    # @param [String] string The string you want to strip.
    # @return [String] A string stripped of all IRC color codes.
    def strip_color!(string)
      [@@mirc_color, @@rgb_color, @@ecma48_color].each do |pattern|
        string.gsub!(pattern, '')
      end
      # strip cancellation codes too if there are no formatting codes
      string.gsub!(@@normal) if !has_color?(string)
      return string
    end

    # Strip IRC color codes from a string.
    # @param [String] string The string you want to strip.
    # @return [String] A string stripped of all IRC color codes.
    def strip_color(string)
      string = string.dup
      return strip_color!(string)
    end

    # Strip IRC formatting codes from a string, modifying it in place.
    # @param [String] string The string you want to strip.
    # @return [String] A string stripped of all IRC formatting codes.
    def strip_formatting!(string)
      string.gsub!(@@formatting, '')
      # strip cancellation codes too if there are no color codes
      string.gsub!(@@normal) if !has_color?(string)
      return string
    end

    # Strip IRC formatting codes from a string.
    # @param [String] string The string you want to strip.
    # @return [String] A string stripped of all IRC formatting codes.
    def strip_formatting(string)
      string = string.dup
      return strip_formatting!(string)
    end

    # Apply IRC formatting codes to a string, modifying it in place.
    # @param [*Array] settings A list of color and formatting attributes you
    #   want to apply.
    # @param [String] string A string you want to format.
    # @return [String] A formatted string.
    def irc_format!(*settings, string)
      string = string.dup

      attributes = settings.select {|k| @@attributes.has_key?(k)}.map {|k| @@attributes[k]}
      colors = settings.select {|k| @@colors.has_key?(k)}.map {|k| @@colors[k]}
      if colors.size > 2
        raise ArgumentError, "At most two colors (foreground and background) might be specified"
      end

      attribute_string = attributes.join
      color_string = if colors.empty?
                       ""
                     else
                       "\x03#{colors.join(",")}"
                     end

      prepend = attribute_string + color_string
      append = @@attributes[:reset]

      # attributes act as toggles, so e.g. underline+underline = no
      # underline. We thus have to delete all duplicate attributes
      # from nested strings.
      string.delete!(attribute_string)

      # Replace the reset code of nested strings to continue the
      # formattings of the outer string.
      string.gsub!(/#{@@attributes[:reset]}/, @@attributes[:reset] + prepend)
      string.insert(0, prepend)
      string << append
      return string
    end

    # Apply IRC formatting codes to a string.
    # @param [*Array] settings A list of color and formatting attributes you
    #   want to apply.
    # @param [String] string A string you want to format.
    # @return [String] A formatted string.
    def irc_format(*settings, string)
      string = string.dup
      return irc_format!(*settings, string)
    end
  end
end
