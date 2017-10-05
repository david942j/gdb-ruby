require 'pry'

module GDB
  # For evaluation ruby code in gdb.
  class EvalContext
    attr_reader :gdb # @return [GDB::GDB]

    def initialize(gdb)
      @gdb = gdb
    end

    private

    # Invoke pry, wrapper with some settings.
    #
    # @return [void]
    def invoke_pry
      org = Pry.config.history.file
      # this has no effect if gdb is launched by pry
      Pry.config.history.file = '~/.gdb-pry_history'
      $stdin.cooked { pry }
      Pry.config.history.file = org
    end
  end
end
