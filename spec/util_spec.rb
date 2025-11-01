# frozen_string_literal: true

require 'gdb/util'

describe GDB::Util do
  it 'find_gdb' do
    expect(described_class.find_gdb).to eq 'gdb'
  end
end
