
# Re TODO ####################################

## Specific bugs

 * @RE (A) Styling breaks completely when starting a double quote
 * @RE (A) Styling broken by double-quote fails to correct itself
   when quote is deleted.
 * @RE (B) Trying to open file in non-existent directory fails.
 * @RE (B) Inserts underline as first character when '#' appears
   somewhere
 * @RE (B) Should auto-indent in markdown lists on line wrap
 
## Conceptual

 * Editor should not work on buffers, but on
   an "adapter" that handles the translation
   between the view layout and the buffer locations

## Basic Usability

 * Backwards search
 * Better file choose/completion proc
 * Mini menu/help buffer w/context. E.g. Start
   a Macro, see macro shortcuts
 * Tab handling (or lack thereof)
 * Ability to kill buffers from editor

## Filesystem handling

 * Only write backup file first time after opening
   a buffer.
 * Consider like emacs to not write backups if
   source controlled file?
 * File locking

## Rendering

 * Fix issue with assembly output (compiler) -- Is that down
   down to tabs?
 * A "virtual terminal" Ruby class to handle views that does
   not fill the window and to handle e.g. execution of inferior
   processes like gdb.

## Shared editing

 * Add support for locking of files.
 * Add support for synchronized editing of files.

## Automation

 * "Arexx" like port (using Drb?)

## Cleanups

 * Split out indentation code
 * Split out input / character handling

## DONE ################################################################

 * **DONE** Make Yank buffer an actual (shared) buffer * **DONE** Add support for using a helper, such as i3-msg for multiple views. E.g i3-msg  'split horizontal; exec term e TODO.md'
 * **DONE** Go-to line
 * **DONE** Ensure permissions on the rewritten file are the same as
   on the old. What is the right way of handling this? (in other
   words, how about e.g. acls, attribtes - is it right to truncate
   and rewrite instead? Would prefer atomic replacement from 
   backup/temporary file)
 * Verify reasonable saving rules: https://bitworking.org/news/2009/01/text-editor-saving-routines
   https://news.ycombinator.com/item?id=507064
   https://bugs.launchpad.net/ubuntu/+source/linux/+bug/317781/comments/54
   r.https://www.gnu.org/software/emacs/manual/html_node/emacs/Saving.html
 * **DONE** MVP: Ability to spawn new instance, with file chooser open in right dir
 * **DONE** Proper auto-indent (handle context above)
 * **DONE** Add option to set working dir
 * **DONE** Search
 * **DONE ** Special string class that stores attribute flags or spans,
   so we can safely change attributes and then minimize ANSI
   changes
