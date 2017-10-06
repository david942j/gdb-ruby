require 'gdb/tube/buffer'

module GDB
  # IO-related classes.
  module Tube
    # For simpler IO manipulation.
    class Tube
      # Batch read size.
      READ_SIZE = 4096

      # @param [IO] io_in
      # @param [IO] io_out
      def initialize(io_in, io_out)
        @in = io_in
        @out = io_out
        @buffer = ::GDB::Tube::Buffer.new
      end

      # Read +n+ bytes.
      #
      # @param [Integer] n
      #   Number of bytes.
      #
      # @return [String]
      #   Returns +n+ bytes from current buffer.
      def readn(n)
        partial while @buffer.size < n
        @buffer.get(n)
      end

      # Receive from +io+ until string +str+ appears.
      #
      # @param [String] str
      #   String to be looking for.
      # @param [Boolean] drop
      #   If need keep +str+ in end of returned string.
      #
      # @return [Stirng]
      #   Data.
      def readuntil(str, drop: true)
        cur = readn(str.size)
        cur << readn(1) until cur.index(str)
        cur.slice!(-str.size..-1) if drop
        cur
      end

      # Put to front of buffer.
      #
      # @param [String] str
      #
      # @return [nil]
      def unget(str)
        @buffer.unshift(str)
        nil
      end

      # @param [#to_s] data
      #   Data to be sent.
      #
      # @return [void]
      def puts(data)
        @in.puts(data)
        readuntil(data)
      end

      # Enter interactive mode.
      #
      # @param [Proc] output_hook
      #   Called before flush the output to +$stdout+.
      #
      # @return [void]
      def interact(output_hook = nil)
        @out.ungetc(@buffer.get)
        loop do
          io, = IO.select([$stdin, @out])
          @in.write($stdin.readpartial(READ_SIZE)) if io.include?($stdin)
          next unless io.include?(@out)
          begin
            recv = @out.readpartial(READ_SIZE)
            recv = output_hook.call(recv) if output_hook
            $stdout.write(recv) if recv
            @out.ungetc(@buffer.get) unless @buffer.empty?
          rescue Errno::EIO
            break
          end
        end
      end

      # Close both side.
      #
      # @return [void]
      def close
        @in.close
        @out.close
      end

      # Is {#close} invoked?
      #
      # @return [Boolean]
      def closed?
        @in.closed? && @out.closed?
      end

      private

      def partial
        @buffer << @out.readpartial(READ_SIZE)
      end
    end
  end
end
