# frozen_string_literal: true

require 'pry'

module GDB
  # For evaluation ruby code in gdb.
  class EvalContext
    # @return [GDB::GDB] The gdb instance.
    attr_reader :gdb

    # Instantiate a {EvalContext} object.
    #
    # Each {GDB::GDB} should have exactly one {EvalContext}
    # for evaluating Ruby.
    #
    # @param [GDB::GDB] gdb
    #   The gdb instance.
    def initialize(gdb)
      @gdb = gdb
    end

    private

    # Invoke pry, wrapper with some settings.
    #
    # @return [void]
    def invoke_pry
      org = Pry.config.history_file
      # this has no effect if gdb is launched by pry
      Pry.config.history_file = File.expand_path('~/.gdb-pry_history')
      $stdin.cooked { pry }
      Pry.config.history_file = org
    end
  end
end
