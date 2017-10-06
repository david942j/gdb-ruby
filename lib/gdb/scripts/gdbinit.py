import gdb
import signal

class GDBRuby():

    def __init__(self):
        # with this life is prettier.
        gdb.execute("set confirm off")
        gdb.execute("set verbose off")
        gdb.execute("set pagination off")
        gdb.execute("set step-mode on")
        gdb.execute("set print elements 0")
        gdb.execute("set print pretty on")

    '''
    Hook gdb prompt
    '''
    def hook_gdb_prompt(self):
        self._original_hook = gdb.prompt_hook
        gdb.prompt_hook = self._prompt_hook

    def resume_prompt(self):
        gdb.prompt_hook = self._original_hook

    def _prompt_hook(self, current_prompt):
        return '(gdb-ruby) '

__commands__ = []
def register_command(cls):
    """Decorator for registering new command to GDB."""
    global __commands__
    __commands__.append(cls)
    return cls

class GDBRubyCommand(gdb.Command):
    def __init__(self, klass):
        self.klass = klass
        self.__doc__ = klass._doc_
        super(GDBRubyCommand, self).__init__(klass._cmdline_, gdb.COMMAND_USER)

    def invoke(self, args, _from_tty):
        print("gdb-ruby> " + self.klass._cmdline_ + ' ' + args)

@register_command
class RubyCommand():
    _doc_ = """Evaluate a Ruby command.
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
"""
    _cmdline_ = 'ruby'

@register_command
class PryCommand():
    _doc_ = """Enter Ruby interactive shell.
Everything works like a charm!

Syntax: pry

Example:
    pry
    # [1] pry(#<GDB::EvalContext>)>
"""
    _cmdline_ = 'pry'


if not 'gdbruby' in globals():
    [GDBRubyCommand(c) for c in __commands__]
    gdbruby = GDBRuby()
