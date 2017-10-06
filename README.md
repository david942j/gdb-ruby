[![Build Status](https://travis-ci.org/david942j/gdb-ruby.svg?branch=master)](https://travis-ci.org/david942j/gdb-ruby)
[![Code Climate](https://codeclimate.com/github/david942j/gdb-ruby/badges/gpa.svg)](https://codeclimate.com/github/david942j/gdb-ruby)
[![Issue Count](https://codeclimate.com/github/david942j/gdb-ruby/badges/issue_count.svg)](https://codeclimate.com/github/david942j/gdb-ruby)
[![Test Coverage](https://codeclimate.com/github/david942j/gdb-ruby/badges/coverage.svg)](https://codeclimate.com/github/david942j/gdb-ruby/coverage)
[![Inline docs](https://inch-ci.org/github/david942j/gdb-ruby.svg?branch=master)](https://inch-ci.org/github/david942j/gdb-ruby)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](http://choosealicense.com/licenses/mit/)

# GDB-Ruby

It's time for Ruby lovers to use Ruby in gdb, and... gdb in Ruby!

# Use Ruby in gdb

We provide a binary `gdb-ruby` with usage exactly same as normal gdb,
while has two extra commands: `ruby` and `pry`!

See examples below:

```yaml
$ gdb-ruby -q bash
Reading symbols from bash...(no debugging symbols found)...done.
(gdb) help ruby
Evaluate a Ruby command.
There's an instance 'gdb' for you. See examples.

Syntax: ruby <ruby code>

Examples:
    ruby p 'abcd'
    # "abcd"

Use gdb:
    ruby puts gdb.break('main')
    # Breakpoint 1 at 0x41eed0

Method defined will remain in context:
    ruby def a(b); b * b; end
    ruby p a(9)
    # 81
(gdb) help pry
Enter Ruby interactive shell.
Everything works like a charm!

Syntax: pry

Example:
    pry
    # [1] pry(#<GDB::EvalContext>)>
```

## Integrate with other gdb extensions

Completely NO effort if you want to use **gdb-ruby** with other gdb extension.

For example, I usually use [gef](https://github.com/hugsy/gef) for my gdb.
And everything works as usual when integrated with **gdb-ruby**:

Launching with `$ gdb-ruby -q bash`

![ruby-in-gef](https://i.imgur.com/WMxofSs.png)

# Use gdb in Ruby

Communicate with gdb in your Ruby script.

## Useful methods

Basical usage is use `execute` to do anything you want to execute inside gdb,
while **gdb-ruby** provides some useful methods listed as following:

* `break`: Set break points. Alias: `b`
* `run`: Run. Alias: `r`
* `register`: Get value by register's name. Alias: `reg`
* `text_base`: Get current running program's text base, useful for a PIE binary.
* `pid`: Get the process id of running process.
* `read_memory`: Read process's memory, with friendly type casting. Alias: `readm`
* `write_memory`: Write process's memory, useful for dynamic analysis. Alias: `writem`
* `interact`: Back to normal gdb interactive mode.

All of these methods are fully documented at [online doc](http://www.rubydoc.info/github/david942j/gdb-ruby/master/GDB/GDB), go for it!

## Examples

Play with argv using **gdb-ruby**.

This script does:
1. Set break point at `main`.
2. Get argv using `register` and `read_memory`.
3. Change argv using `write_memory`.

```ruby
require 'gdb'

# launch a gdb instance
gdb = GDB::GDB.new('bash')

# 1. set breakpoint
gdb.break('main')
#=> "Breakpoint 1 at 0x41eed0"
gdb.run('-c "echo cat"')

# 2. get argv pointers
rdi = gdb.reg(:rdi)
#=> 3
rsi = gdb.reg(:rsi)
argv = gdb.readm(rsi, rdi, as: :uint64)
argv.map{ |c|'0x%x' % c }
#=> ['0x7fffffffe61b', '0x7fffffffe625', '0x7fffffffe628']

# 3. overwrite argv[2]'s 'cat' to 'FAT'
gdb.writem(argv[2] + 5, 'FAT') # echo FAT

puts gdb.execute('continue')
# Continuing.
# FAT
# [Inferior 1 (process 32217) exited normally]
```

Set a break point, run it, and back to gdb interactive mode.

```ruby
require 'gdb'

# launch a gdb instance
gdb = GDB::GDB.new('bash')
# set breakpoints
gdb.break('main')
gdb.run
# shows process do running
gdb.execute('info reg rip')
#=> "rip            0x41eed0\t0x41eed0 <main>"

# interaction like normal gdb!
gdb.interact
```

# Installation

Available on RubyGems.org!
```
$ gem install gdb
```

# Development

```
git clone https://github.com/david942j/gdb-ruby
cd gdb-ruby
bundle
bundle exec rake
```

# Bugs & feedbacks

Feel free to file an issue if you find any bugs.
Any feature requests and suggestions are welcome! :grimacing:

# Growing up

**gdb-ruby** is under developing, give it a star and [watching](https://github.com/david942j/gdb-ruby/subscription)
for latest updates!
