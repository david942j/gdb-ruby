require 'io/console'
require 'pty'
require 'readline'

require 'gdb/tube/tube'

module GDB
  # For launching a gdb process.
  class GDB
    # Absolute path to python scripts.
    SCRIPTS_PATH = File.join(__dir__, 'scripts').freeze

    def initialize(arguments, gdb: 'gdb')
      arguments = '-q' + ' ' + arguments # XXX
      @tube = spawn(gdb + ' ' + arguments)
      @tube.puts("source #{File.join(SCRIPTS_PATH, 'gdbinit.py')}")
      @prompt = '(gdb-ruby) '
      @tube.readuntil(@prompt)
    end

    # Execute a command in gdb.
    #
    # @param [String] cmd
    #   Command to be executed.
    #
    # @return [String]
    #   The execution result returned by gdb.
    #
    # @example
    #   gdb = GDB::GDB.new('bash')
    #   gdb.execute('b main')
    #   #=> "Breakpoint 1 at 0x41eed0"
    #   gdb.execute('run')
    #   gdb.execute('print $rsi')
    #   #=> "$1 = 0x7fffffffdef8"
    def execute(cmd)
      @tube.puts(cmd)
      @tube.readuntil(@prompt).strip
    end

    # Enter gdb interactive mode.
    # Gdb will be closed after interaction.
    #
    # @return [void]
    def interact
      # resume prompt
      @tube.puts('python gdbruby.resume_prompt()')
      $stdin.raw { @tube.interact }
      close
    end

    # Terminate the gdb process.
    #
    # @return [void]
    def close
      @tube.close
      Process.wait(@gdb_pid)
      nil
    end
    alias quit close

    private

    TIOCSWINSZ = 0x5414

    def spawn(cmd)
      output, input, @gdb_pid = PTY.spawn(cmd)
      output.ioctl(TIOCSWINSZ, [*IO.console.winsize, 0, 0].pack('S*'))
      ::GDB::Tube::Tube.new(input, output)
    end
  end
end
