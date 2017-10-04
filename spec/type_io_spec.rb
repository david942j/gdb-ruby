#encoding: ascii-8bit
#
require 'gdb/type_io'

describe GDB::TypeIO do
  before(:all) do
    @get_io = -> (str) { described_class.new(StringIO.new(str)) }
  end
  describe 'read' do
    it 'string' do
      io = @get_io["0123456789ABCDE\x80\n"]
      expect(io.read(0, 2)).to eq '01'
      expect(io.read(13, 4)).to eq "DE\x80\n"
      expect(io.read(13, 100)).to eq "DE\x80\n"
    end

    it 'build-in types' do
      # test them ALL
      io = @get_io["\xef\xbe\xad\xde\x0c\xb0\xce\xfaAAAAAAAA"]
      expect(io.read(0, 4, as: :int8)).to eq [-17, -66, -83, -34]
      expect(io.read(0, 1, as: :int16)).to be -0x4111
      expect(io.read(0, 1, as: :int32)).to be -0x21524111
      expect(io.read(0, 1, as: :int64)).to be -0x5314ff321524111
      expect(io.read(0, 1, as: :int128)).to eq 0x4141414141414141faceb00cdeadbeef
      expect(io.read(0, 4, as: :uint8)).to eq [0xef, 0xbe, 0xad, 0xde]
      expect(io.read(0, 1, as: :uint16)).to eq 0xbeef
      expect(io.read(0, 1, as: :uint32)).to be 0xdeadbeef
      expect(io.read(0, 1, as: :uint64)).to eq 0xfaceb00cdeadbeef
      expect(io.read(0, 1, as: :uint128)).to eq 0x4141414141414141faceb00cdeadbeef

      io = @get_io["\x80"]
      expect(io.read(0, 1, as: :uint8)).to be 0x80
      expect(io.read(0, 1, as: :int8)).to be -128
    end

    it 'unsupported' do
      expect { @get_io[''].read(0, 1, as: :meowmeow) }.to raise_error(ArgumentError)
    end

    it 'block' do
      io = @get_io["\x04ABCD\x03AAA\x00\x04meow"]
      res = io.read(0, 4) do |io|
        len = io.read(1).ord
        io.read(len)
      end
      expect(res).to eq ['ABCD', 'AAA', '', 'meow']
    end
  end

  describe 'write' do
    it 'write' do
      io = @get_io['']
      io.write(0, 'AAA')
      expect(io.read(0, 3)).to eq 'AAA'
    end
  end
end
