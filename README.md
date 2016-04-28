# quick-highlight [![Build Status](https://travis-ci.org/t9md/atom-quick-highlight.svg?branch=master)](https://travis-ci.org/t9md/atom-quick-highlight)

- Highlight selected and multiple persisting highlight across visible editor.
![gif](https://raw.githubusercontent.com/t9md/t9md/f51b8e211e9ed8ed455053be52d5505da876b298/img/atom-quick-highlight.gif)

- Show found count on StatusBar.
![gif](https://raw.githubusercontent.com/t9md/t9md/a00e64b9dd85b851ad23c28e830f4a7d7dbe6dcf/img/atom-quick-highlight.png)

# Commands

- `quick-highlight:toggle` toggle highlight for selected or cursor word.
- `quick-highlight:clear` clear all highlight.
- `vim-mode-plus-user:quick-highlight` Operator for [vim-mode-plus](https://atom.io/packages/vim-mode-plus).

# Keymap

No default keymap.

e.g.
* general
```coffeescript
'atom-workspace atom-text-editor:not([mini])':
  'cmd-k m': 'quick-highlight:toggle'
  'cmd-k M': 'quick-highlight:clear'
```

* vim-mode user
```coffeescript
'atom-text-editor.vim-mode.normal-mode, atom-text-editor.vim-mode.visual-mode':
  'space m': 'quick-highlight:toggle'
  'space M': 'quick-highlight:clear'
```

* vim-mode-plus user
```coffeescript
'atom-text-editor.vim-mode-plus.normal-mode, atom-text-editor.vim-mode-plus.visual-mode':
  'space m': 'quick-highlight:toggle'
  'space M': 'quick-highlight:clear'
  'g m': 'vim-mode-plus-user:quick-highlight'
```

## vim-mode-plus operator

You can quick-highlight with combination of any motion, text-object.  
Since it's operator, yes can repat with `.`.

e.g.
- `gmiw`: highlight `inner-word`.
- `gmil`: highlight `inner-line`.
- `gmi'`: highlight `inner-single-quote`.
- `v2lgm`: highlight three visually selected character..

# Display found count on StatusBar

By default, when you highlight new text by `quick-highlight:toggle`, found count is displayed on StatusBar.  
You can configure CSS class to use with `countDisplayStyles`.  
See. `styleguide:show` for available style classes.  

e.g.
- Default: `badge icon icon-location`
- e.g. 2: `badge badge-error icon icon-bookmark`
- e.g. 3: `badge badge-success icon icon-light-bulb`
- e.g. 4: `btn btn-primary selected inline-block-tight`

# TODO

* [x] Improve default to dynamically change using [color-channel](http://lesscss.org/functions/#color-channel)?
* [ ] Highlight with RegExp.
