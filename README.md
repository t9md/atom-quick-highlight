# quick-highlight

Quickly highlight selected text or current word.

![gif](https://raw.githubusercontent.com/t9md/t9md/3b13d5fb6134b0b393e0a18b27bdd9c7b4350ace/img/atom-quick-highlight.gif)

Show found count on StatusBar.
![gif](https://raw.githubusercontent.com/t9md/t9md/a00e64b9dd85b851ad23c28e830f4a7d7dbe6dcf/img/atom-quick-highlight.png)

# How to use

From command palette
* invoke `quick-highlight:toggle` to toggle highlight.
* invoke `quick-highlight:clear` to clear all highlight.

Or set keymap for above commands for quicker access.

# Keymap

No default keymap, choose your preference.

e.g.

* general
```coffeescript
'atom-workspace atom-text-editor:not([mini])':
  'cmd-k m': 'quick-highlight:toggle'
  'cmd-k M': 'quick-highlight:clear'
```

* vim-mode user
```coffeescript
'atom-text-editor.vim-mode.command-mode, atom-text-editor.vim-mode.visual-mode':
  'space m': 'quick-highlight:toggle'
  'space M': 'quick-highlight:clear'
```

# Display found count on StatusBar

By default, when you highlight new text with `quick-highlight:toggle`, found count is displayed on StatusBar.  
You can configure CSS class to use with `countDisplayStyles`.  
See. `styleguide:show` for available style classes.  

e.g.
- Default: `badge icon icon-location`
- Case-1: `badge badge-error icon icon-bookmark`
- Case-2: `badge badge-success icon icon-light-bulb`
- Case-3: `btn btn-primary selected inline-block-tight`

# TODO

* [ ] Improve default to dynamically change using [color-channel](http://lesscss.org/functions/#color-channel)?
* [ ] Make color configurable.
* [ ] Serialize, deserialize
* [ ] Highlight with RegExp.
* [x] Show matched count on statusbar?
* [ ] Wrap highlight with HTMLElement, to be able to use full color.
* [x] Refresh only added/deleted decoration for performance.
* [x] auto highlight for newly added texts while editiong.
* [x] highlight across visible buffer.
* [x] Or some configurable decoration style like outline, underline.

# Limitation

* Currently, color must be transparent, it need some work.
See [discussion](https://discuss.atom.io/t/editor-marker-css/8616) here
