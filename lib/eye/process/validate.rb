require 'shellwords'
require 'etc'

module Eye::Process::Validate
  class Error < Exception; end

  def normalize_config(config)
    h = config

    h[:working_dir] = '/' unless h[:working_dir]
    h[:pid_file] = Eye::System.normalized_file(h[:pid_file], h[:working_dir]) if h[:pid_file]
    h[:stdout] = Eye::System.normalized_file(h[:stdout], h[:working_dir]) if h[:stdout]
    h[:stderr] = Eye::System.normalized_file(h[:stderr], h[:working_dir]) if h[:stderr]

    if h[:environment]
      env = h[:environment]

      (h[:environment] || {}).each do |k,v|
        env[k.to_s] = v.to_s if v
      end

      h[:environment] = env
    end

    h
  end

  def validate(config)
    if (str = config[:start_command])
      # it should parse with Shellwords and not raise
      spl = Shellwords.shellwords(str) * '#'

      if config[:daemonize]
        if spl =~ %r[sh#\-c|#&&#|;#]
          raise Error, "#{config[:name]}, start_command in daemonize not supported shell concats like '&&'"
        end
      end
    end

    if config[:daemonize]
      # pid_file should be writable
    end

    Shellwords.shellwords(config[:stop_command]) if config[:stop_command]
    Shellwords.shellwords(config[:restart_command]) if config[:restart_command]

    Etc.getpwnam(config[:uid]) if config[:uid]
    Etc.getpwnam(config[:gid]) if config[:gid]

    if config[:working_dir]
      raise Error, "working_dir '#{config[:working_dir]}' is invalid" unless File.directory?(config[:working_dir])
    end
  end

end
