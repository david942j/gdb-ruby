require 'io/console'
require 'pty'
require 'readline'

require 'gdb/eval_context'
require 'gdb/gdb_error'
require 'gdb/tube/tube'
require 'gdb/type_io'

module GDB
  # For launching a gdb process.
  class GDB
    # Absolute path to python scripts.
    SCRIPTS_PATH = File.join(__dir__, 'scripts').freeze

    # To launch a gdb instance.
    #
    # @param [String] arguments
    #   The command line arguments to pass to gdb. See examples.
    #
    # @param [String] gdb
    #   Name of gdb.
    #
    # @example
    #   gdb = GDB::GDB.new('-q -nh bash')
    #   gdb = GDB::GDB.new('arm.elf', gdb: 'gdb-multiarch')
    def initialize(arguments, gdb: 'gdb')
      arguments = "--command=#{File.join(SCRIPTS_PATH, 'gdbinit.py')}" + ' ' + arguments # XXX
      @tube = spawn(gdb + ' ' + arguments)
      pre = @tube.readuntil('GDBRuby:')
      @prompt = @tube.readuntil("\n").strip
      @tube.unget(pre + @tube.readuntil(@prompt))
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
    alias exec execute

    # Set break point.
    #
    # This method some magic, see parameters or examples.
    #
    # @param [Integer, String] point
    #   If +Integer+ is given, will be translated as set break point
    #   at address +point+, i.e. equivalent to +break *<integer>+.
    #   If +String+ is given, equivalent to invoke +execute("break <point>")+.
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
    #   puts gdb.run('-c "echo 111"')
    #   # Starting program: /bin/bash -c "echo 111"
    #   # 111
    #   # [Inferior 1 (process 3229) exited normally]
    #   #=> nil
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
      check_alive!
      Integer(python_p("gdb.parse_and_eval('$#{reg_name}')").split.first)
    end
    alias reg register

    # Get the process's text base.
    #
    # @return [Integer]
    #   The base address.
    #
    # @note
    #   This will also set a variable +$text+ in gdb.
    def text_base
      check_alive!
      base = Integer(execute('info proc stat').scan(/Start of text: (.*)/).flatten.first)
      execute("set $text = #{base}")
      base
    end
    alias code_base text_base

    # Is process running?
    #
    # Actually judged by if {#pid} returns zero.
    #
    # @return [Boolean]
    #   True for process is running.
    def alive?
      !pid.zero?
    end
    alias running? alive?

    # Get the process's pid.
    #
    # This method implemented by invoking +python print(gdb.selected_inferior().pid)+.
    #
    # @return [Integer]
    #   The pid of process. If process is not running, zero is returned.
    def pid
      @pid = python_p('gdb.selected_inferior().pid').to_i
    end

    # Read current process's memory.
    #
    # See {TypeIO#read} for details.
    #
    # @param [Mixed] args
    #   See {TypeIO#read}.
    #
    # @return [Object]
    #   See {TypeIO#read}.
    #
    # @yieldparam [IO] io
    #   See {TypeIO#read}.
    #
    # @yieldreturn [Object]
    #   See {TypeIO#read}.
    #
    # @example
    #   # example of fetching argv
    #   gdb = GDB::GDB.new('spec/binaries/amd64.elf')
    #   gdb.break('main')
    #   gdb.run('pusheen the cat')
    #   gdb.read_memory(0x400000, 4)
    #   #=> "\x7fELF"
    #   argc = gdb.register(:rdi)
    #   #=> 4
    #   args = gdb.read_memory(gdb.register(:rsi), argc, as: :uint64)
    #   Array.new(3) do |i|
    #     gdb.read_memory(args[i + 1], 1) do |m|
    #       str = ''
    #       str << m.read(1) until str.end_with?("\x00")
    #       str
    #     end
    #   end
    #   #=> ["pusheen\x00", "the\x00", "cat\x00"]
    #
    #   # or, use our build-in types listed in {TypeIO::TYPES}
    #   gdb.read_memory(args[1], 3, as: :cstring)
    #   #=> ["pusheen\x00", "the\x00", "cat\x00"]
    def read_memory(*args, &block)
      check_alive! # this would set @pid
      File.open("/proc/#{@pid}/mem", 'rb') do |f|
        ::GDB::TypeIO.new(f).read(*args, &block)
      end
    end
    alias readm read_memory

    # Write a string to process at specific address.
    #
    # @param [Integer] addr
    #   Target address.
    # @param [String] str
    #   String to be written.
    #
    # @return [Integer]
    #   Bytes written.
    def write_memory(addr, str)
      check_alive! # this would set @pid
      File.open("/proc/#{@pid}/mem", 'wb') do |f|
        ::GDB::TypeIO.new(f).write(addr, str)
      end
    end
    alias writem write_memory

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
      $stdin.raw { @tube.interact(method(:output_hook)) }
      close
    end

    # Terminate the gdb process.
    #
    # @return [void]
    def close
      return if @tube.closed?
      @tube.close
      Process.wait(@gdb_pid)
      nil
    end
    alias quit close

    private

    # Raise {GDBError} if process is not running.
    #
    # @return [nil]
    def check_alive!
      raise GDBError, 'Process is not running' unless alive?
    end

    TIOCSWINSZ = 0x5414

    def spawn(cmd)
      output, input, @gdb_pid = PTY.spawn(cmd)
      output.ioctl(TIOCSWINSZ, [*IO.console.winsize, 0, 0].pack('S*'))
      ::GDB::Tube::Tube.new(input, output)
    end

    COMMAND_PREFIX = 'gdb-ruby> '.freeze

    # @param [String] output
    #
    # @return [String]
    def output_hook(output)
      idx = output.index(COMMAND_PREFIX)
      return yield output.gsub(@prompt, '') if idx.nil?
      yield output.slice!(0, idx)
      cmd, args = output.slice(COMMAND_PREFIX.size..-1).split(' ', 2)
      # only support ruby and pry now.
      return yield output unless %w[ruby pry].include?(cmd)
      args = 'send(:invoke_pry)' if cmd == 'pry'
      # gdb by default set tty
      # hack it
      `stty opost onlcr`
      begin
        eval_context.instance_eval(args)
      rescue StandardError, ScriptError => e
        $stdout.puts("#{e.class}: #{e}")
      end
      @tube.puts('END')
      @tube.readuntil(@prompt)
      nil
    end

    def eval_context
      @context ||= ::GDB::EvalContext.new(self)
    end
  end
end
