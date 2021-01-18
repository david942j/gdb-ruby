lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'

require 'gdb/version'

Gem::Specification.new do |s|
  s.name          = 'gdb'
  s.version       = ::GDB::VERSION
  s.date          = Date.today.to_s
  s.summary       = 'GDB Ruby-binding plus Ruby interactive shell in GDB'
  s.description   = <<-EOS
It's time for Ruby lovers to use Ruby in gdb and gdb in Ruby!

Achieve two things in one gem:

1. Launching Ruby interactive shell (pry) in gdb.
2. gdb Ruby-binding, i.e. communicate with gdb in Ruby scripts.
  EOS
  s.license       = 'MIT'
  s.authors       = ['david942j']
  s.email         = ['david942j@gmail.com']
  s.homepage      = 'https://github.com/david942j/gdb-ruby'
  s.files         = Dir['lib/**/*.{rb,py}'] + %w(README.md)
  s.require_paths = ['lib']
  s.executables   = ['gdb-ruby']

  s.required_ruby_version = '>= 2.3'

  s.add_dependency 'pry', '~> 0.11'
  s.add_dependency 'memory_io', '~> 0.2'

  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.8'
  s.add_development_dependency 'rubocop', '~> 1'
  s.add_development_dependency 'simplecov', '~> 0.17', '< 0.22'
  s.add_development_dependency 'tty-platform', '~> 0.1'
  s.add_development_dependency 'yard', '~> 0.9'
end
