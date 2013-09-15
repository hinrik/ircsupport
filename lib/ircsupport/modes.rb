module IRCSupport
  module Modes
    module_function

    # Parse mode changes.
    # @param [Array] modes The modes you want to parse. A string of mode
    #   changes (e.g. `'-i+k+l'`) followed by any arguments (e.g. `'secret', 25`).
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

    # Parse channel mode changes.
    # @param [Array] modes The modes you want to parse.
    # @option opts [Hash] :chanmodes The channel modes which are allowed. This is
    #   the same as the "CHANMODES" isupport option.
    # @option opts [Hash] :statmodes The channel modes which are allowed. This is
    #   the same as the keys of the "PREFIX" isupport option.
    # @return [Array] Each element will be a hash with three keys: `:set`,
    #   a boolean indicating whether the mode is being set (instead of unset);
    #   `:mode`, the mode character; and `:argument`, the argument to the mode,
    #   if any.
    def parse_channel_modes(modes, opts = {})
      chanmodes = opts[:chanmodes] || {
        'A' => %w{b e I}.to_set,
        'B' => %w{k}.to_set,
        'C' => %w{l}.to_set,
        'D' => %w{i m n p s t a q r}.to_set,
      }
      statmodes = opts[:statmodes] || %w{o h v}.to_set

      mode_changes = []
      modelist, *args = modes
      parse_modes(modelist).each do |mode_change|
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

    # Condense mode string by removing duplicates.
    # @param [String] modes A string of modes you want condensed.
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

    # Calculate the difference between two mode strings.
    # @param [String] before The "before" mode string.
    # @param [String] after The "after" mode string.
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
  end
end
