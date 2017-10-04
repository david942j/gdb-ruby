module GDB
  # Support read / write custom defined tpyes.
  class TypeIO
    class << self
      # Read a little endian integer.
      #
      # @param [#read] io
      # @param [Integer] byte
      # @param [:signed, :unsigned] sign
      #   Signed or unsigned integer.
      #
      # @return [Integer]
      #   The read integer.
      #
      # @example
      #   read_integer(StringIO.new("\x80"), 1, :signed)
      #   #=> -128
      def read_integer(io, byte, sign)
        str = io.read(byte).reverse # little endian
        val = str.bytes.reduce(0) { |sum, b| sum * 256 + b }
        if sign == :signed && val >= (1 << (8 * byte - 1))
          val -= 1 << (8 * byte)
        end
        val
      end
    end

    # Supported built-in types.
    TYPES = {
      string: nil, # will be special handled
      int8:   ->(io) { TypeIO.read_integer(io, 1, :signed) },
      int16:  ->(io) { TypeIO.read_integer(io, 2, :signed) },
      int32:  ->(io) { TypeIO.read_integer(io, 4, :signed) },
      int64:  ->(io) { TypeIO.read_integer(io, 8, :signed) },
      int128: ->(io) { TypeIO.read_integer(io, 16, :signed) },

      uint8:   ->(io) { TypeIO.read_integer(io, 1, :unsigned) },
      uint16:  ->(io) { TypeIO.read_integer(io, 2, :unsigned) },
      uint32:  ->(io) { TypeIO.read_integer(io, 4, :unsigned) },
      uint64:  ->(io) { TypeIO.read_integer(io, 8, :unsigned) },
      uint128: ->(io) { TypeIO.read_integer(io, 16, :unsigned) }
    }.freeze

    # Instantiate a {TypeIO} object.
    #
    # @param [IO, #pos=, #read, #write] io
    #   The IO file.
    def initialize(io)
      @io = io.binmode
    end

    # Read from memory.
    #
    # @param [Integer] addr
    #   Address to be read.
    #
    # @param [Integer] size
    #   Number of data to be read. See params +as+ for details.
    #
    # @param [Symbol] as
    #   The needed returned type.
    #   Note that the total bytes be read will be +size * sizeof(as)+.
    #   For example, if +as+ equals +:int32+, +size * 4+ bytes would be read,
    #   and returned type is array of 32 bits signed integers.
    #
    #   Supported types are listed in {TypeIO::TYPES}, all integer-like types
    #   are seen as little endian. If you need big endian or other fashion things, pass a block
    #   instead of using parameter +as+.
    #
    # @yieldparam [IO] io
    #   If block is given, the parameter +as+ would be ignored.
    #   Block would be invoked +size+ times, and the returned object would be collected into
    #   one array and returned.
    #
    #   This is convenient for reading non-stable size objects, i.e. c++'s string object.
    #   See examples for clearer usage.
    #
    # @yieldreturn [Object]
    #   Whatever object you like.
    #
    # @return [String, Object, Array<Object>]
    #   If +as+ equals to +:string+, the string with length +size+ would be returned.
    #   Otherwise, array of objects would be returned.
    #   An exception is when +size+ equals to 1, the read object would be returned
    #   instead of create an array with only one element.
    #
    # @example
    #   io = TypeIO.new(StringIO.new("AAAA"))
    #   io.read(0, 3)
    #   #=> "AAA"
    #   io.read(0, 1, as: :uint32)
    #   #=> 1094795585 # 0x41414141
    #
    #   io = TypeIO.new(StringIO.new("\xef\xbe\xad\xde"))
    #   io.read(0, 4, as: :int8)
    #   #=> [-17, -66, -83, -34]
    #
    #   io = TypeIO.new(StringIO.new("\x04ABCD\x03AAA\x00\x04meow"))
    #   io.read(0, 4) do |m|
    #     len = m.read(1).ord
    #     m.read(len)
    #   end
    #   #=> ['ABCD', 'AAA', '', 'meow']
    def read(addr, size, as: :string)
      @io.pos = addr
      if block_given?
        return yield @io if size == 1
        Array.new(size) { yield @io }
      else
        raise ArgumentError, "Unsupported types #{as.inspect}" unless TYPES.key?(as)
        return @io.read(size) if as == :string
        read(addr, size, &TYPES[as])
      end
    end

    # Write a string at specific address.
    #
    # @param [Integer] addr
    #   Target address.
    # @param [String] str
    #   String to be written.
    #
    # @return [Integer]
    #   Bytes written.
    def write(addr, str)
      @io.pos = addr
      @io.write(str)
    end
  end
end
