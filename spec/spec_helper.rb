require 'fileutils'
require 'io/wait'
require 'rspec'
require 'securerandom'
require 'simplecov'
require 'tmpdir'
require 'tty/platform'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter]
)
SimpleCov.start do
  add_filter '/spec/'
end

module Helpers
  def linux_only!
    skip 'Linux only' unless TTY::Platform.new.linux?
  end

  # @param [Array<String>] ary
  def hook_stdin_out(*ary, prompt: '(gdb) ')
    old_stdin = $stdin.dup
    old_stdout = $stdout.dup
    $stdin = StringIO.new
    $stdout = StringIO.new
    buffer = ''
    allow(IO).to receive(:select) do |*args|
      args.first.delete($stdin)
      out, = args.first
      if out.ready?
        begin
          s = out.readpartial(4096)
          buffer << s
          out.ungetc(s)
        rescue Errno::EIO
        ensure next [[out]]
        end
      end
      next [[out]] if ary.empty?
      next [[]] if buffer.index(prompt).nil?
      $stdin.string = ary.shift + "\n"
      buffer.slice!(0, buffer.index(prompt) + prompt.size)
      [[$stdin]]
    end

    class << $stdin
      def raw
        yield
      end

      def readpartial(_size)
        self.gets
      end
    end
    yield
  ensure
    $stdin.close
    $stdin = old_stdin
    $stdout = old_stdout
  end

  def with_tempfile
    filename = File.join(Dir.tmpdir, 'gdb-ruby-' + SecureRandom.hex(4))
    yield filename
  ensure
    FileUtils.rm_f(filename)
  end
end

class String
  def uncolorize
    self.gsub(/\e\[([;\d]+)?m/, '')
  end
  alias uc uncolorize
end
RSpec.configure do |c|
  c.include Helpers
end
