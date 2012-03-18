module IRCSupport
  module Modes
    # @param [Array] modes The modes you want to parse.
    # @return [Array] Each element will be a hash with two keys: `:set`,
    #   a boolean indicating whether the mode is being set (instead of unset);
    #   and `:mode`, the mode character.
    def parse_modes(modes)
      mode_changes = []
      modes.scan(/[-+]\w+/).each do |modegroup|
        set, modegroup = modegroup.split '', 2
        set = set == '+' ? true : false
        modegroup.split('').each do |mode|
          mode_changes << { set: set, mode: mode }
        end
      end
      return mode_changes
    end

    # @param [Array] modes The modes you want to parse.
    # @option opts [Hash] :chanmodes The channel modes which are allowed. This is
    #   the same as the "CHANMODES" isupport option.
    # @option opts [Hash] :statmodes The channel modes which are allowed. This is
    #   the same as the keys of the "PREFIX" isupport option.
    # @return [Array] Each element will be a hash with three keys: `:set`,
    #   a boolean indicating whether the mode is being set (instead of unset);
    #   `:mode`, the mode character; and `:argument`, the argument to the mode,
    #   if any.
    def parse_channel_modes(modeparts, opts = {})
      chanmodes = opts[:chanmodes] || {
        'A' => %w{b e I},
        'B' => %w{k},
        'C' => %w{l},
        'D' => %w{i m n p s t a q r},
      }
      statmodes = opts[:statmodes] || %w{o h v}

      mode_changes = []
      modes, *args = modeparts
      parse_modes(modes).each do |mode_change|
        set, mode = mode_change[:set], mode_change[:mode]
        case
        when chanmodes["A"].include?(mode) || chanmodes["B"].include?(mode)
          mode_changes << {
            mode: mode,
            set: set,
            argument: args.shift
          }
        when chanmodes["C"].include?(mode)
          mode_changes << {
            mode: mode,
            set: set,
            argument: args.shift.to_i
          }
        when chanmodes["D"].include?(mode)
          mode_changes << {
            mode: mode,
            set: set,
          }
        else
          raise ArgumentError, "Unknown mode: #{mode}"
        end
      end

      return mode_changes
    end

    # @param [String] modes A string of modes you want to condense
    #   (remove duplicates).
    # @return [Strings] A condensed mode string.
    def condense_modes(modes)
      action = nil
      result = ''
      modes.split(//).each do |mode|
        if mode =~ /[+-]/ and (!action or mode != action)
          result += mode
          action = mode
          next
        end
        result += mode if mode =~ /[^+-]/
      end
      result.sub!(/[+-]\z/, '')
      return result
    end

    # @param [String] before The "before" mode string.
    # @param [String] after The "before" mode string.
    # @return [String] A modestring representing the difference between the
    #   two mode strings.
    def diff_modes(before, after)
      before_modes = before.split(//)
      after_modes = after.split(//)
      removed = before_modes - after_modes
      added = after_modes - before_modes
      result = removed.map { |m| '-' + m }.join
      result << added.map { |m| '+' + m }.join
      return condense_modes(result)
    end

    module_function :parse_modes, :parse_channel_modes, :condense_modes, :diff_modes
  end
end
