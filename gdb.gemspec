lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'

require 'gdb/version'

Gem::Specification.new do |s|
  s.name          = 'gdb'
  s.version       = ::GDB::VERSION
  s.date          = Date.today.to_s
  s.summary       = 'GDB Ruby-binding and Ruby command in GDB'
  s.description   = <<-EOS
It's time for Ruby lovers to use Ruby in gdb, and gdb in Ruby!
  EOS
  s.license       = 'MIT'
  s.authors       = ['david942j']
  s.email         = ['david942j@gmail.com']
  s.homepage      = 'https://github.com/david942j/gdb-ruby'
  s.files         = Dir['lib/**/*.{rb,py}'] + %w(README.md)
  s.require_paths = ['lib']
  s.executables   = ['gdb-ruby']

  s.required_ruby_version = '>= 2.1.0'

  s.add_dependency 'pry', '~> 0.11'
  s.add_dependency 'memory_io', '~> 0.1.1'

  s.add_development_dependency 'rake', '~> 12.3'
  s.add_development_dependency 'rspec', '~> 3.8'
  s.add_development_dependency 'rubocop', '~> 0.60'
  s.add_development_dependency 'simplecov', '~> 0.15'
  s.add_development_dependency 'yard', '~> 0.9'
end
