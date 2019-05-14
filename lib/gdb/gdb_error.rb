# frozen_string_literal: true

module GDB
  # Raise this error if the request will fail in gdb.
  class GDBError < StandardError
  end
end
