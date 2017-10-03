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
      gdb.execute('set follow-fork-mode parent')
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
end
