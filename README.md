# quick-highlight

Quickly highlight selected text or current word.

![gif](https://raw.githubusercontent.com/t9md/t9md/7e10eb6f4e34015305073257dc258fd37cb16846/img/atom-quick-highlight.gif)

# Development stage

Currently feature is very limited, but I publish this even if limited, I think this still useful for others.

# Limitation

* Currently, color must be transparent, it need some work.
See [discussion](https://discuss.atom.io/t/editor-marker-css/8616) here

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


# TODO
Lot of todo.

* [ ] Refresh only added/deleted decoration for performance.

* [ ] Make color configurable.
* [ ] Serialize, deserialize
* [ ] Highlight with RegExp.
* [ ] Show matched count on statusbar?
* [ ] Wrap highlight with HTMLElement, to be able to use full color.
* [x] auto highlight for newly added texts while editiong.
* [x] highlight across visible buffer.
* [x] Or some configurable decoration style like outline, underline.
