# frozen_string_literal: true

require 'gdb/gdb'

describe 'command' do
  before(:all) do
    @new_gdb = lambda do
      gdb = GDB::GDB.new('-q -nh spec/binaries/amd64.elf')
      # make gdb out more stable
      out = gdb.instance_variable_get(:@tube).instance_variable_get(:@out)
      org_method = out.method(:readpartial)
      allow(out).to receive(:readpartial) do |size|
        ret = str = org_method.call(size)
        if str.include?("\n")
          ret = str.slice!(0, str.index("\n") + 1)
          out.ungetc(str)
        end
        ret
      end
      gdb
    end
  end

  describe 'ruby' do
    it 'simple' do
      hook_stdin_out('help ruby', 'ruby puts 123', 'ruby p a', # raise error
                     'quit') do
        @new_gdb.call.interact
        expect($stdout.printable_string).to include(<<-EOS.strip)
(gdb) help ruby
Evaluate a Ruby command.
There's an instance 'gdb' for you. See examples.

Syntax: ruby <ruby code>

Examples:
    ruby p 'abcd'
    # "abcd"

Use gdb:
    ruby puts gdb.break('main')
    # Breakpoint 1 at 0x41eed0

Method defined will remain in context:
    ruby def a(b); b * b; end
    ruby p a(9)
    # 81

(gdb) ruby puts 123
123
(gdb) ruby p a
NameError: undefined local variable or method
        EOS
      end
    end

    it 'run' do
      linux_only!

      hook_stdin_out('ruby gdb.break("main")', 'ruby gdb.run', 'info reg $rip',
                     'quit') do
        @new_gdb.call.interact
        expect($stdout.printable_string.gsub("\t", ' ' * 12)).to include(<<-EOS)
(gdb) ruby gdb.break("main")
(gdb) ruby gdb.run
(gdb) info reg $rip
rip            0x40062a            0x40062a <main+4>
(gdb) quit
        EOS
      end
    end
  end

  it 'python exception' do
    hook_stdin_out('ruby puts gdb.exec("invalid command")', 'quit') do
      @new_gdb.call.interact
      expect($stdout.printable_string).to include(<<-EOS)
(gdb) ruby puts gdb.exec("invalid command")
Undefined command: "invalid".  Try "help".
(gdb) quit
      EOS
    end
  end

  it 'pry' do
    # so hard to test.. just make sure the `$stdin.cooked` has been invoked
    # also check setting of Pry.config.history.file
    hook_stdin_out('help pry', 'pry', 'quit') do
      enter_pry = false
      allow($stdin).to receive(:cooked) do
        expect(Pry.config.history_file).to eq File.expand_path('~/.gdb-pry_history')
        enter_pry = true
      end
      @new_gdb.call.interact
      expect(enter_pry).to be true
      expect($stdout.printable_string).to include(<<-EOS)
(gdb) help pry
Enter Ruby interactive shell.
Everything works like a charm!

Syntax: pry

Example:
    pry
    # [1] pry(#<GDB::EvalContext>)>

(gdb) pry
(gdb) quit
      EOS
    end
  end

  it 'rsource' do
    with_tempfile do |temp|
      File.binwrite(temp, <<-RUBY)
def method_after_rsource!
end
      RUBY
      hook_stdin_out(
        'ruby method_after_rsource!',
        "rsource #{temp}",
        'ruby method_after_rsource!',
        'quit'
      ) do
        @new_gdb.call.interact
        output = $stdout.printable_string
        expect(output).to include(<<-EOS.strip)
(gdb) ruby method_after_rsource!
NoMethodError: undefined method
        EOS
        expect(output).to include(<<-EOS)
(gdb) rsource #{temp}
(gdb) ruby method_after_rsource!
(gdb) quit
        EOS
      end
    end
  end
end
