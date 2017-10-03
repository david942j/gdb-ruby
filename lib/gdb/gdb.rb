require 'io/console'
require 'pty'
require 'readline'

require 'gdb/gdb_error'
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

    # Set break point.
    #
    # This function does some magic, see params.
    #
    # @param [Integer, String] point
    #   If +Integer+ is given, will be translated as set break point
    #   at address +point+, i.e. equivalent to +break *<integer>+.
    #   If +String+ is given, equivalent to invoke +execve('break <point>')+.
    #
    # @return [String]
    #   Returns what gdb displayed after set a break point.
    #
    # @example
    #   gdb = GDB::GDB.new('bash')
    #   gdb.break('main')
    #   #=> "Breakpoint 1 at 0x41eed0"
    #   gdb.break(0x41eed0)
    #   #=> "Note: breakpoint 1 also set at pc 0x41eed0.\r\nBreakpoint 2 at 0x41eed0"
    def break(point)
      case point
      when Integer then execute("break *#{point}")
      when String then execute("break #{point}")
      end
    end
    alias b break

    # Run process.
    #
    # @param [String] args
    #   Arguments to pass to run command.
    #
    # @return [String]
    #   Returns what gdb displayed.
    #
    # @example
    #   gdb = GDB::GDB.new('bash')
    #   gdb.execute('set follow-fork-mode parent')
    #   gdb.run('-c "echo 111"')
    #   #=> TODO
    #
    # @note
    #   If breakpoints are not set properly and cause gdb hangs,
    #   this method will hang, too.
    def run(args = '')
      execute('run ' + args)
    end
    alias r run

    # Get current value of register
    #
    # @param [String, Symbol] reg_name
    #
    # @return [Integer]
    #   Value of desired register.
    #
    # @todo
    #   Handle when +reg_name+ is not a general-purpose register.
    def register(reg_name)
      raise GDBError, 'Process is not running' unless alive?
      Integer(python_p("gdb.parse_and_eval('$#{reg_name}')"))
    end
    alias reg register

    # Is process running?
    #
    # Actually judged by output of .
    def alive?
      !pid.zero?
    end
    alias running? alive?

    # Get the process's pid.
    #
    # This method implemented by invoke +python print(gdb.selected_inferior().pid)+.
    # @return [Integer]
    #   The pid of process. If process is not running, zero is returned.
    def pid
      python_p('gdb.selected_inferior().pid').to_i
    end

    # To simplify the frequency call of +python print(xxx)+.
    #
    # @param [String] cmd
    #   python command.
    # @return [String]
    #   Execution result.
    def python_p(cmd)
      execute("python print(#{cmd})")
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
