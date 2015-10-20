# quick-highlight [![Build Status](https://travis-ci.org/t9md/atom-quick-highlight.svg)](https://travis-ci.org/t9md/atom-quick-highlight)
Quickly highlight selected text or word under cursor.  
The highlights are persists until you clear.

![gif](https://raw.githubusercontent.com/t9md/t9md/6724f957cc71cbdc82e8a97ae1beac20327090cf/img/atom-quick-highlight.gif)

Show found count on StatusBar.
![gif](https://raw.githubusercontent.com/t9md/t9md/a00e64b9dd85b851ad23c28e830f4a7d7dbe6dcf/img/atom-quick-highlight.png)

# Commands

- `quick-highlight:toggle` toggle highlight for selected or under cursor keyword.
- `quick-highlight:clear` clear all highlight.

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
```

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

* [ ] Improve default to dynamically change using [color-channel](http://lesscss.org/functions/#color-channel)?
* [ ] Highlight with RegExp.
* [x] Show matched count on statusbar?
* [x] Refresh only added/deleted decoration for performance.
* [x] auto highlight for newly added texts while editiong.
* [x] highlight across visible buffer.
* [x] Or some configurable decoration style like outline, underline.

# Limitation

* Currently, color must be transparent, it need some work.
See [discussion](https://discuss.atom.io/t/editor-marker-css/8616) here
