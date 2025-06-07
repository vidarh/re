
Re depends on a number of helpers. Currently those helpers are
adapted to my setup and mine alone.

This directory contains copies of my versions of the helpers.

Biggest issues:

* You need a wrapper in your path to call the editor as "re"
* You need `rofi` installed. The file selector will optionally
  try `fzf` instead but I haven't tested it without rofi for a long
  time.
* For spliting buffers horizontally or vertically, the
  scripts assume you're running bspwm (with commented out versions
  for i3wm). This isn't even true for me anymore - I just haven't
  had time to update it.

Plan:

* The "helperregistry" in `lib/re/helperregistry.rb` should be
  changed to point to these scripts by default.
* The specific paths should be put in a config file.
* The scripts in this dir should be changed to at least *work*
  on other systems than mine.

