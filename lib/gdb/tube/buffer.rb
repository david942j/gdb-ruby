module GDB
  module Tube
    # IO buffer.
    class Buffer
      attr_reader :size # @return [Integer] size

      def initialize
        @data = []
        @size = 0
      end

      # Push string into buffer.
      #
      # @param [String] str
      #   String to push.
      #
      # @return [Buffer]
      #   Returns self so this method is chainable.
      def <<(str)
        str = str.to_s.dup
        return self if str.empty?
        @data << str
        @size += str.size
        self
      end

      def empty?
        @size.zero?
      end

      # Retrieves at most +n+ bytes from buffer.
      #
      # @param [Integer?] n
      #   Maximum number of bytes. +n+ equals +nil+ for unlimited.
      #
      # @return [String]
      #   Retrieved string.
      def get(n = nil)
        if n.nil? || n >= @size
          ret = @data.join
          @data.clear
          @size = 0
        else
          now = 0
          idx = @data.find_index do |s|
            if s.size + now >= n
              true
            else
              now += s.size
              false
            end
          end
          ret = @data.slice!(0, idx + 1).join
          back = ret.slice!(n..-1)
          @data.unshift(back) unless back.empty?
          @size -= n
        end
        ret
      end

      # Push front.
      #
      # @param [String] str
      #   String to be push.
      #
      # @return [void]
      def unshift(str)
        return if str.nil? || str.empty?
        @data.unshift(str)
        @size += str.size
      end
    end
  end
end
