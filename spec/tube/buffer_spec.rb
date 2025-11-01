# frozen_string_literal: true

require 'gdb/tube/buffer'

describe GDB::Tube::Buffer do
  before(:all) do
    @buffer = described_class.new
  end

  it '<<' do
    @buffer << 'meow' << 'a' << '' << 123
    expect(@buffer.size).to be 8
    expect(@buffer.instance_variable_get(:@data)).to eq %w[meow a 123]
    expect(@buffer.get).to eq 'meowa123'
  end

  it 'mixed' do
    @buffer << 'meow'
    expect(@buffer.get(2)).to eq 'me'
    expect(@buffer.size).to be 2
    expect(@buffer.get).to eq 'ow'
  end

  it 'empty?' do
    expect(@buffer.empty?).to be_truthy
  end

  it 'unshift' do
    @buffer << 'abc'
    @buffer.unshift('123')
    expect(@buffer.get).to eq '123abc'
  end
end
