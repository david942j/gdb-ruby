lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'

require 'gdb/version'

Gem::Specification.new do |s|
  s.name          = 'gdb'
  s.version       = ::GDB::VERSION
  s.date          = Date.today.to_s
  s.summary       = 'Use gdb in ruby!'
  s.description   = <<-EOS
  It's time for ruby lovers to use gdb in ruby, and... use ruby in gdb!
  EOS
  s.license       = 'MIT'
  s.authors       = ['david942j']
  s.email         = ['david942j@gmail.com']
  s.homepage      = 'https://github.com/david942j/gdb-ruby'
  s.files         = Dir['lib/**/*.rb'] + %w(README.md Rakefile)
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.1.0'

  s.add_development_dependency 'codeclimate-test-reporter', '~> 0.6'
  s.add_development_dependency 'pry', '~> 0.10'
  s.add_development_dependency 'rake', '~> 12.1'
  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'rubocop', '~> 0.49'
  s.add_development_dependency 'simplecov', '~> 0.15'
  s.add_development_dependency 'yard', '~> 0.9'
end
