# frozen_string_literal: true

require 'io/console'
require 'memory_io'
require 'pty'
require 'readline'

require 'gdb/eval_context'
require 'gdb/gdb_error'
require 'gdb/tube/tube'
require 'gdb/util'

module GDB
  # For launching a gdb process.
  #
  # @!macro [new] gdb_displayed
  #   @return [String]
  #     Returns what gdb displayed after executing this command.
  class GDB
    # Absolute path to the python scripts.
    SCRIPTS_PATH = File.join(__dir__, 'scripts').freeze

    # Used by private methods only.
    COMMAND_PREFIX = 'gdb-ruby> '

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
      gdb_bin = ::GDB::Util.which(gdb)
      raise Errno::ENOENT, gdb if gdb_bin.nil?

      arguments = "--command=#{File.join(SCRIPTS_PATH, 'gdbinit.py')} #{arguments}" # XXX
      @tube = spawn("#{gdb_bin} #{arguments}")
      pre = @tube.readuntil('GDBRuby:')
      @prompt = @tube.readuntil("\n").strip
      @tube.unget(pre + @tube.readuntil(@prompt))
    end

    # Execute a command in gdb.
    #
    # @param [String] cmd
    #   Command to be executed.
    #
    # @!macro gdb_displayed
    #
    # @example
    #   gdb = GDB::GDB.new('bash')
    #   gdb.execute('b main')
    #   #=> "Breakpoint 1 at 0x41eed0"
    #   gdb.execute('run')
    #   gdb.execute('print $rsi')
    #   #=> "$1 = 0x7fffffffdef8"
    def execute(cmd)
      # clear tube if not in interactive mode
      @tube.clear unless interacting?

      @tube.puts(cmd)
      @tube.readuntil(@prompt).strip
    end
    alias exec execute

    # Set breakpoints.
    #
    # This method does some magic, see examples.
    #
    # @param [Integer, String] point
    #   If +Integer+ is given, will be translated as set break point
    #   at address +point+, i.e. equivalent to +break *<integer>+.
    #   If +String+ is given, equivalent to invoke +execute("break <point>")+.
    #
    # @!macro gdb_displayed
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

    # Run the process.
    #
    # @param [String] args
    #   Arguments to pass to +run+ command.
    #
    # @!macro gdb_displayed
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
    #   this method hangs as well.
    def run(args = '')
      execute("run #{args}")
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

    # Is the process running?
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
    #   The pid of the process. If the process is not running, zero is returned.
    def pid
      @pid = python_p('gdb.selected_inferior().pid').to_i
    end

    # Execute +continue+ command.
    #
    # @!macro gdb_displayed
    #
    # @note
    #   This method may block the IO if no breakpoints are properly set.
    def continue
      check_alive!
      execute('continue')
    end

    # Execute +info+ command.
    #
    # @param [String] args
    #   Arguments to pass to +info+ command.
    #
    # @!macro gdb_displayed
    #
    # @example
    #   gdb = GDB::GDB.new('spec/binaries/amd64.elf')
    #   gdb.break('main')
    #   gdb.run
    #   puts gdb.info('proc stat')
    #   # process 32537
    #   # cmdline = '/home/gdb-ruby/spec/binaries/amd64.elf'
    #   # cwd = '/home/gdb-ruby'
    #   # exe = '/home/gdb-ruby/spec/binaries/amd64.elf'
    #   gdb.close
    def info(args = '')
      execute("info #{args}")
    end

    # Read current process's memory.
    #
    # @param [Integer, String] addr
    #   Address to start to read.
    #   +addr+ can be a string like 'heap+0x10'.
    #   Supported variables are names in /proc/$pid/maps such as +heap/libc/stack/ld+.
    #
    # @param [Integer] num_elements
    #   Number of elements to read.
    #   If +num_elements+ equals to 1, an object read will be returned.
    #   Otherwise, an array with size +num_elements+ will be returned.
    #
    # @option [Symbol, Class] as
    #   Types that supported by [MemoryIO](https://github.com/david942j/memory_io).
    #
    # @return [Object, Array<Object>]
    #   Return types are decided by value of +num_elements+ and option +as+.
    #
    # @yieldparam [IO] io
    #   The +IO+ object that points to +addr+,
    #   read from it.
    #
    # @yieldreturn [Object]
    #   Whatever you read from +io+.
    #
    # @example
    #   gdb = GDB::GDB.new('spec/binaries/amd64.elf')
    #   gdb.break('main')
    #   gdb.run
    #   gdb.read_memory('amd64.elf', 4)
    #   #=> "\x7fELF"
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
    #   args = gdb.read_memory(gdb.register(:rsi), argc, as: :u64)
    #   Array.new(3) do |i|
    #     gdb.read_memory(args[i + 1], 1) do |m|
    #       str = ''
    #       loop do
    #         c = m.read(1)
    #         break if c == "\x00"
    #         str << c
    #       end
    #       str
    #     end
    #   end
    #   #=> ["pusheen", "the", "cat"]
    #
    #   # or, use our build-in types of gem +memory_io+.
    #   gdb.read_memory(args[1], 3, as: :c_str)
    #   #=> ["pusheen", "the", "cat"]
    def read_memory(addr, num_elements, options = {}, &block)
      check_alive! # this would set @pid
      options[:as] = block if block_given?
      MemoryIO.attach(@pid).read(addr, num_elements, **options)
    end
    alias readm read_memory

    # Write an object to process at specific address.
    #
    # @param [Integer, String] addr
    #   Target address.
    #   +addr+ can be a string like 'heap+0x10'.
    #   Supported variables are names in +/proc/$pid/maps+ such as +heap/libc/stack/ld+.
    # @param [Objects, Array<Objects>] objects
    #   Objects to be written.
    #
    # @option [Symbol, Class] as
    #   See {#read_memory}.
    #
    # @return [void]
    def write_memory(addr, objects, options = {}, &block)
      check_alive! # this would set @pid
      options[:as] = block if block_given?
      MemoryIO.attach(@pid).write(addr, objects, **options)
    end
    alias writem write_memory

    # To simplify the frequency call of +python print(xxx)+.
    #
    # @param [String] cmd
    #   python command.
    #
    # @return [String]
    #   Execution result.
    def python_p(cmd)
      execute("python print(#{cmd})")
    end

    # Enter gdb interactive mode.
    # GDB will be closed after interaction.
    #
    # @return [void]
    def interact
      return if interacting?

      @interacting = true
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

    def interacting?
      defined?(@interacting)
    end

    # Raise {GDBError} if process is not running.
    #
    # @return [void]
    def check_alive!
      raise GDBError, 'Process is not running' unless alive?
    end

    def spawn(cmd)
      output, input, @gdb_pid = PTY.spawn(cmd)
      IO.console && output.winsize = IO.console.winsize
      ::GDB::Tube::Tube.new(input, output)
    end

    # @param [String] output
    #
    # @yieldparam [String] output
    # @yieldreturn [void]
    #
    # @return [void]
    def output_hook(output)
      idx = output.index(COMMAND_PREFIX)
      return yield output.gsub(@prompt, '') if idx.nil?

      yield output.slice!(0, idx)
      cmd, args = output.slice(COMMAND_PREFIX.size..-1).split(' ', 2)
      # only support ruby and pry now.
      return yield output unless %w[ruby pry rsource].include?(cmd)

      args = case cmd
             when 'pry' then '__send__(:invoke_pry)'
             when 'rsource' then File.read(File.expand_path(args.strip))
             else args
             end
      args = '__send__(:invoke_pry)' if cmd == 'pry'
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
      @eval_context ||= ::GDB::EvalContext.new(self)
    end
  end
end
