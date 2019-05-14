# frozen_string_literal: true

module GDB
  # Defines utility methods.
  module Util
    module_function

    # Cross-platform way of finding an executable in the $PATH.
    #
    # @param [String] cmd
    # @return [String?]
    # @example
    #   which('ruby')
    #   #=> "/usr/bin/ruby"
    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        end
      end
      nil
    end

    # The name of gdb could be:
    #   - gdb
    #   - ggdb (macOS)
    # @return [String?]
    # @example
    #   find_gdb
    #   #=> 'gdb'
    def find_gdb
      %w[gdb ggdb].find { |n| which(n) }
    end
  end
end
