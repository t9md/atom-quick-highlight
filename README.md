# quick-highlight [![Build Status](https://travis-ci.org/t9md/atom-quick-highlight.svg?branch=master)](https://travis-ci.org/t9md/atom-quick-highlight)

- Highlight selected and multiple persisting highlight across visible editor.
![gif](https://raw.githubusercontent.com/t9md/t9md/f51b8e211e9ed8ed455053be52d5505da876b298/img/atom-quick-highlight.gif)

- Show found count on StatusBar.
![gif](https://raw.githubusercontent.com/t9md/t9md/a00e64b9dd85b851ad23c28e830f4a7d7dbe6dcf/img/atom-quick-highlight.png)

# Commands

- `quick-highlight:toggle` toggle highlight for selected or cursor word.
- `quick-highlight:clear` clear all highlight.

And following two operator for [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user.
- `vim-mode-plus-user:quick-highlight`: Operator to highlight by text-object or motion.
- `vim-mode-plus-user:quick-highlight-word` Highlight cursor word, similar to `quick-highlight:toggle`, but well fit for vim's block cursor orientation. And `.` repeatable.

# Keymap

No default keymap.

e.g.
* general
```coffeescript
'atom-workspace atom-text-editor:not([mini])':
  'cmd-k m': 'quick-highlight:toggle'
  'cmd-k M': 'quick-highlight:clear'
```

* vim-mode-plus user
```coffeescript
'atom-text-editor.vim-mode-plus.normal-mode, atom-text-editor.vim-mode-plus.visual-mode':
  'space m': 'vim-mode-plus-user:quick-highlight-word'
  'space M': 'quick-highlight:clear'
  'g m': 'vim-mode-plus-user:quick-highlight'
```

## Modify highlight style

You can override style in you `style.less`.
See example below.

```less
@import "syntax-variables";

// For selection color
//=======================
atom-text-editor .quick-highlight.box-selection .region {
  border-width: 1px;
  background-color: transparent;
  border-color: @syntax-text-color;
}

// Make underline manual highlight prioritized(come front) over other highlight
//=======================
// Mixin to set z-index of quick-highlight manual color
.quick-highlight-z-index(@name, @value) {
  .quick-highlight.@{name} .region {
    z-index: @value;
  }
}

// quick-highlight use 0 to 7 color
//  for box style, use box-01 to box-07
//  for highlight style, use highlight-01 to highlight-07
.quick-highlight-z-index(underline-01, 1);
.quick-highlight-z-index(underline-02, 1);
.quick-highlight-z-index(underline-03, 1);
.quick-highlight-z-index(underline-04, 1);
.quick-highlight-z-index(underline-05, 1);
.quick-highlight-z-index(underline-06, 1);
.quick-highlight-z-index(underline-07, 1);
```

## vim-mode-plus operator

You can quick-highlight with combination of any motion, text-object.  
Since it's operator, yes can repeat by `.`.

e.g.
- `g m i w`: highlight `inner-word`.
- `g m i l`: highlight `inner-line`.
- `g m i'`: highlight `inner-single-quote`.
- `v 2 l g m`: highlight three visually selected character..

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
