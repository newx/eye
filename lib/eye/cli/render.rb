module Eye::Cli::Render
private

  def render_info(data)
    error!("unexpected server answer #{data.inspect}") unless data.is_a?(Hash)

    make_str data
  end

  def make_str(data, level = -1)
    return nil if !data || data.empty?

    if data.is_a?(Array)
      data.map{|el| make_str(el, level) }.compact * "\n"
    else
      str = nil

      if data[:name]
        return make_str(data[:subtree], level) if data[:name] == '__default__'

        off = level * 2
        off_str = ' ' * off
        name = (data[:type] == :application && !data[:state]) ? "\033[1m#{data[:name]}\033[0m" : data[:name].to_s
        off_len = (data[:type] == :application && data[:state]) ? 20 : 35
        str = off_str + (name + ' ').ljust(off_len - off, data[:state] ? '.' : ' ')

        if data[:debug]
          str += ' | ' + debug_str(data[:debug])

          # for group show chain data
          if data[:debug][:chain]
            str += " (chain: #{data[:debug][:chain].map(&:to_i)})"
          end
        elsif data[:state]
          str += ' ' + data[:state].to_s
          str += '  (' + resources_str(data[:resources]) + ')' if data[:resources] && data[:state].to_sym == :up
          str += " (#{data[:state_reason]} at #{data[:state_changed_at].to_s(:short)})" if data[:state_reason] && data[:state] == 'unmonitored'
        elsif data[:current_command]
          chain_progress = if data[:chain_progress]
            " #{data[:chain_progress][0]} of #{data[:chain_progress][1]}" rescue ''
          end
          str += " \e[1;33m[#{data[:current_command]}#{chain_progress}]\033[0m"
          str += " (#{data[:chain_commands] * ', '})" if data[:chain_commands]
        end

      end

      if data[:subtree].nil?
        str
      elsif !data[:subtree] && data[:type] != :application
        nil
      else
        [str, make_str(data[:subtree], level + 1)].compact * "\n"
      end
    end
  end

  def resources_str(r)
    return '' if !r || r.empty?

    res = "#{r[:start_time]}, #{r[:cpu]}%"
    res += ", #{r[:memory] / 1024}Mb" if r[:memory]
    res += ", <#{r[:pid]}>"

    res
  end

  def render_debug_info(data)
    error!("unexpected server answer #{data.inspect}") unless data.is_a?(Hash)

    s = ""

    config = data.delete(:config)

    data.each do |k, v|
      s << "#{"#{k.to_s.capitalize}:".ljust(10)} "

      case k
      when :resources
        s << resources_str(v)
      else
        s << "#{v}"
      end

      s << "\n"
    end

    s << "\n"

    if config
      s << YAML.dump(config)
    end

    s
  end

  def render_history(data)
    error!("unexpected server answer #{data.inspect}") unless data.is_a?(Hash)

    res = []
    data.each do |name, data|
      res << detail_process_info(name, data)
    end

    res * "\n"
  end

  def detail_process_info(name, history)
    return if history.empty?

    res = "\033[1m#{name}\033[0m:\n"
    history = history.reverse

    history.chunk{|h| [h[:state], h[:reason].to_s] }.each do |_, hist|
      if hist.size >= 3
        res << detail_process_info_string(hist[0])
        res << detail_process_info_string(:state => "... #{hist.size - 2} times", :reason => '...', :at => hist[-1][:at])
        res << detail_process_info_string(hist[-1])
      else
        hist.each do |h|
          res << detail_process_info_string(h)
        end
      end
    end

    res
  end

  DF = '%d %b %H:%M'

  def detail_process_info_string(h)
    state = h[:state].to_s.ljust(14)
    "#{Time.at(h[:at]).strftime(DF)} - #{state} (#{h[:reason]})\n"
  end

end
