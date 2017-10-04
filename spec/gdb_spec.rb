#encoding: ascii-8bit

require 'gdb/gdb'

describe GDB::GDB do
  before(:all) do
    @binpath = ->(f) { File.join(__dir__, 'binaries', f) }
    @new_gdb = lambda do |f, args: '', &block|
      gdb = described_class.new(args + ' ' + @binpath[f])
      block.call(gdb)
      gdb.close
    end
  end

  it 'initialize' do
    @new_gdb.call('amd64.elf') do |gdb|
      expect(gdb.execute('break main')).to eq 'Breakpoint 1 at 0x4005da'
    end

    @new_gdb.call('amd64.pie.elf', args: '-nh') do |gdb|
      expect(gdb.execute('break main')).to eq 'Breakpoint 1 at 0x814'
      expect(gdb.execute('run').lines.map(&:strip).join("\n")).to eq <<-EOS.strip
Starting program: #{@binpath['amd64.pie.elf']}

Breakpoint 1, 0x0000555555554814 in main ()
      EOS
    end

    @new_gdb.call('amd64.pie.strip.elf') do |gdb|
      expect(gdb.execute('break main')).to eq 'Function "main" not defined.'
    end
  end

  it 'break' do
    @new_gdb.call('amd64.elf') do |gdb|
      expect(gdb.break('main')).to eq 'Breakpoint 1 at 0x4005da'
      expect(gdb.b(0x4005da)).to eq "Note: breakpoint 1 also set at pc 0x4005da.\r\nBreakpoint 2 at 0x4005da"
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
    @new_gdb.call('bash', args: '-nh') do |gdb|
      expect(gdb.run('-c "echo 1111"').lines[1].strip).to eq '1111'
    end
  end

  it 'register' do
    @new_gdb.call('amd64.elf') do |gdb|
      expect { gdb.register(:rdi) }.to raise_error(GDB::GDBError)
      gdb.b('main')
      gdb.run
      expect(gdb.register(:rdi)).to be 1
      expect(gdb.register(:rax)).to be 0x4005d6
      expect(gdb.register(:al)).to be 0xd6
    end
  end

  it 'read_memory' do
    @new_gdb.call('amd64.elf') do |gdb|
      gdb.b('main')
      gdb.run('pusheen the cat')
      expect(gdb.read_memory(0x400000, 4)).to eq "\x7fELF"
      # Lets fetch argv
      argc = gdb.register(:rdi)
      args = gdb.read_memory(gdb.register(:rsi), argc, as: :uint64)
      ary = Array.new(argc) do |i|
        next 'argv0' if i == 0
        gdb.read_memory(args[i], 1) do |m|
          str = ''
          str << m.read(1) until str.end_with?("\x00")
          str[0..-2]
        end
      end
      expect(ary).to eq %w[argv0 pusheen the cat]
    end
  end

  it 'write_memory' do
    @new_gdb.call('bash', args: '-nh') do |gdb|
      gdb.b('main')
      gdb.r('-c "echo 123"')
      argv2 = gdb.read_memory(gdb.register(:rsi) + 16, 1, as: :uint64)
      expect(gdb.read_memory(argv2, 8)).to eq 'echo 123'
      gdb.write_memory(argv2 + 5, 'ABC')
      pid = gdb.pid
      expect(gdb.execute('continue').lines.map(&:strip).join("\n")).to eq <<-EOS.strip
Continuing.
ABC
[Inferior 1 (process #{pid}) exited normally]
      EOS
    end
  end
end
