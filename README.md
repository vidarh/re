
# Re

An experimental editor written in Ruby.

Re uses DRb to implement a primitive client-server
model (primitive as there are far more notifications 
than needed and far more redraws than needed as a 
consquence).

It tries to keep a dump of the state of open buffers in
a JSON file for sessin recovery. Buffers remain open as long as the
server process lives currently (not way of killing
them).

Emacs style frame splits (alt+2/alt+3) are currently
hardcoded to expect i3wm to open new view processes
in new windows

Undo/Redo is buggy.

Note that the code is horribly ugly and in need of
refactoring. 

## Keyboard shortcuts

(likely outdated)

* `Ctrl-Q` quits
* `Ctrl-S` saves
* `Ctrl-P` (previous), or the `Up` arrow key, moves the cursor up
* `Ctrl-N` (next), or the `Down` arrow key, moves the cursor down
* `Ctrl-F` (forward), or the `Right` arrow key, moves the cursor right
* `Ctrl-B` (backward), or the `Left` arrow key, moves the cursor left
* `Ctrl-A` or `Home` moves the cursor to the beginning of the line
* `Ctrl-E` or `End` moves the cursor to the end of the line
* `Ctrl-H` or `Backspace` deletes the previous character
* `Ctrl-D` or `Delete` deletes the current character
* `Ctrl-U` deletes the line text before the cursor
* `Ctrl-K` deletes the line text after (and including) the cursor
* `Ctrl--` undoes the last change
* `Ctrl-R` reloads from disk.

## License

[The Unlicense](https://github.com/agorf/femto/blob/master/LICENSE)

## Authors

I (Vidar Hokstad) took [Femto](https://github.com/agorf/femto)
by Angelos Orfanakos, <https://agorf.gr/> as a starting point,
and modified it extensively.

There's not much left of Femto in here, so all blame for bugs here goes to Vidar.
