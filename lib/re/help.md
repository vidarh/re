# HELP - Re v0.1

If opened within current buffer, [Meta + F2] to return

## Keyboard mappings

[Ctrl + o]   Open

[Meta + F1]  Open at cursor
[Meta + F2]  Open previous

### Ctrl + X
[Ctrl X + b] Switch buffer
[Ctrl X + f] Show filename
[Ctrl X + l] Toggle show line numbers
[Ctrl X + p] Pry
[Ctrl X + r] Reload current buffer
[Ctrl X + t] Select Rouge theme

### CUA

[Ctrl + right] Next word
[Ctrl + left]  Previous word
[Ctrl + up]    Page up
[Ctrl + down]  Page down

[f1]   Help

## Personal macros [FIXME: separate personal help]

[f5]   Update matches
[f6]   Paragraph reformat
[f7]   Wordcount
[f8]   Insert DONE header
[f9]   Insert date
[f10]  Run eslint
[f11]  Rerun project command
[f12]  Run project command

"project-command" is any command defined in package.json

## .workspace.json

```json
{
  "name": "some name",
  "ssh-host": "default ssh host",
  "project": {
    "e|w|n|s": {
      "opts": "--ratio 0.7 -o 0.8",
      "e|w|n|s": "!command to execute"
    }
  }
}
```
