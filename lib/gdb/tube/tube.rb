# frozen_string_literal: true

require 'gdb/tube/buffer'

module GDB
  # IO-related classes.
  module Tube
    # For simpler IO manipulation.
    class Tube
      # Batch read size.
      READ_SIZE = 4096

      # Instantiate a {Tube::Tube} object.
      #
      # @param [IO] io_in
      #   Input.
      # @param [IO] io_out
      #   Output.
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

      # Clear received data.
      #
      # @return [String]
      #   The data cleared.
      #   An empty string is returned if the buffer is already empty.
      def clear
        @buffer.get
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
        return data.split("\n").each(&method(:puts)) if data.strip.include?("\n")

        @in.puts(data)
        readuntil("\n")
      end

      # Enter interactive mode.
      #
      # @param [Proc] output_hook
      #   String received from output would be passed into this proc.
      #   Only data yielded by this proc would be flushed to +$stdout+.
      #
      #   Use <tt>lambda { |s, &block| block.call(s) }</tt> or +:tap.to_proc+ (since Ruby 2.2)
      #   for a do-nothing hook.
      #
      # @return [void]
      def interact(output_hook)
        @out.ungetc(@buffer.get)
        loop do
          io, = IO.select([$stdin, @out])
          @in.write($stdin.readpartial(READ_SIZE)) if io.include?($stdin)
          next unless io.include?(@out)

          begin
            recv = @out.readpartial(READ_SIZE)
            output_hook.call(recv) { |str| $stdout.write(str) }
            @out.ungetc(@buffer.get) unless @buffer.empty?
          rescue Errno::EIO, EOFError
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
