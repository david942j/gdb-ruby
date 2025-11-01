# encoding: ascii-8bit
# frozen_string_literal: true

require 'tempfile'

require 'gdb/gdb'

describe GDB::GDB do
  before(:all) do
    linux_only!

    @binpath = ->(f) { File.join('spec', 'binaries', f) }
    @new_gdb = lambda do |f, &block|
      gdb = described_class.new("-q --nx #{@binpath[f]}")
      block.call(gdb)
      gdb.close
    end
  end

  it 'initialize' do
    @new_gdb.call('amd64.elf') do |gdb|
      expect(gdb.execute('break main').make_printable).to eq 'Breakpoint 1 at 0x40062a'
    end

    @new_gdb.call('amd64.pie.elf') do |gdb|
      expect(gdb.execute('break main').make_printable).to eq 'Breakpoint 1 at 0x854'
      expect(gdb.execute('run').lines.first.strip).to eq <<-EOS.strip
Starting program: #{File.realpath(@binpath['amd64.pie.elf'])}
      EOS
      expect(gdb.exec('invalid command')).to eq 'Undefined command: "invalid".  Try "help".'
    end

    @new_gdb.call('amd64.pie.strip.elf') do |gdb|
      expect(gdb.execute('break main')).to eq 'Function "main" not defined.'
    end
  end

  it 'break' do
    @new_gdb.call('amd64.elf') do |gdb|
      expect(gdb.break('main').make_printable).to eq 'Breakpoint 1 at 0x40062a'
      expect(gdb.b(0x40062a).make_printable).to eq "Note: breakpoint 1 also set at pc 0x40062a.\nBreakpoint 2 at 0x40062a"
    end
  end

  it 'alive?' do
    @new_gdb.call('amd64.elf') do |gdb|
      gdb.b('main')
      expect(gdb.alive?).to be false
      gdb.run
      expect(gdb.alive?).to be true
    end
  end

  it 'run' do
    @new_gdb.call('amd64.elf') do |gdb|
      expect(gdb.run('1111').lines[1].strip).to eq '1111'
    end

    # issue#37
    @new_gdb.call('amd64.elf') do |gdb|
      expect(gdb.run('A' * 200)).to include('Starting') # only check it not hangs
    end
  end

  it 'register' do
    @new_gdb.call('amd64.elf') do |gdb|
      expect { gdb.register(:rdi) }.to raise_error(GDB::GDBError)
      gdb.b('main')
      gdb.run
      expect(gdb.register(:rdi)).to be 1
      expect(gdb.register(:rax)).to be 0x400626
      expect(gdb.register(:ah)).to be 0x6
      expect(gdb.register(:rip)).to be 0x40062a
    end
  end

  it 'info' do
    @new_gdb.call('amd64.elf') do |gdb|
      gdb.b('main')
      expect(gdb.info('b').make_printable).to eq <<-EOS.strip
Num     Type           Disp Enb Address            What
1       breakpoint     keep y   0x000000000040062a <main+4>
      EOS
    end
  end

  it 'text_base' do
    @new_gdb.call('amd64.elf') do |gdb|
      gdb.b('main')
      gdb.r
      expect(gdb.text_base).to be 0x400000
    end

    @new_gdb.call('amd64.pie.elf') do |gdb|
      gdb.b('main')
      stop = gdb.r.make_printable.scan(/Breakpoint 1, 0x(.*) in main \(\)/).flatten.first.to_i(16)
      expect(gdb.text_base).to eq stop & -4096
    end
  end

  it 'read_memory' do
    @new_gdb.call('amd64.elf') do |gdb|
      gdb.b('main')
      gdb.run('pusheen the cat')
      expect(gdb.read_memory(0x400000, 4)).to eq "\x7fELF"
      expect(gdb.read_memory('amd64.elf', 4)).to eq "\x7fELF"
      # Lets fetch argv
      argc = gdb.register(:rdi)
      args = gdb.read_memory(gdb.register(:rsi), argc, as: :u64)
      ary = Array.new(argc) do |i|
        next 'argv0' if i == 0

        gdb.read_memory(args[i], 1) do |m|
          str = +''
          loop do
            c = m.read(1)
            break if c == "\x00"

            str << c
          end
          str
        end
      end
      expect(ary).to eq %w[argv0 pusheen the cat]

      expect(gdb.read_memory(args[1], 3, as: :c_str)).to eq %w[pusheen the cat]
    end
  end

  it 'write_memory' do
    @new_gdb.call('amd64.elf') do |gdb|
      gdb.b('main')
      gdb.r('pusheen "the cat"')
      argv2 = gdb.read_memory(gdb.register(:rsi) + 16, 1, as: :u64)
      expect(gdb.read_memory(argv2, 7)).to eq 'the cat'
      gdb.write_memory(argv2 + 4, 'FAT')
      pid = gdb.pid
      expect(gdb.continue.lines.map(&:strip).join("\n")).to eq <<-EOS.strip
Continuing.
pusheen
the FAT
[Inferior 1 (process #{pid}) exited normally]
      EOS
    end
  end

  it 'interact' do
    hook_stdin_out('b main', 'run', 'quit') do
      @new_gdb.call('amd64.elf', &:interact)
      expect($stdout.printable_string).to include <<-EOS
(gdb) b main
Breakpoint 1 at 0x40062a
(gdb) run
Starting program: #{File.realpath(@binpath['amd64.elf'])}#{' '}

Breakpoint 1, 0x000000000040062a in main ()
(gdb) quit
      EOS
    end
    # test for issue #2
    hook_stdin_out('set prompt gdb>', 'quit', prompt: '') do
      @new_gdb.call('amd64.elf', &:interact)
      output = $stdout.printable_string
      expect(output).to include <<-EOS
(gdb) set prompt gdb>
      EOS
      expect(output).to include <<-EOS
gdb>quit
      EOS
    end
  end
end
