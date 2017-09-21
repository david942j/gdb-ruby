import gdb

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


gdbruby = GDBRuby()
gdbruby.hook_gdb_prompt()
