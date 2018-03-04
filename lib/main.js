const {CompositeDisposable, Emitter} = require('atom')

let KeywordManager

module.exports = {
  activate (state) {
    this.emitter = new Emitter()
    this.toggle = this.toggle.bind(this)
    const toggle = this.toggle

    this.subscriptions = new CompositeDisposable(
      atom.commands.add('atom-text-editor:not([mini])', {
        'quick-highlight:toggle' () {
          toggle(getCursorWord(this.getModel()))
        },
        'quick-highlight:clear': () => this.keywordManager && this.keywordManager.clear()
      }),
      atom.config.observe('quick-highlight.highlightSelection', value => {
        if (value) this.getKeywordManager() // To initialize
      })
    )
  },

  deactivate () {
    if (this.keywordManager) this.keywordManager.destroy()
    this.subscriptions.dispose()
    this.keywordManager = null
    this.subscriptions = null
  },

  getKeywordManager () {
    if (!KeywordManager) KeywordManager = require('./keyword-manager')
    if (!this.keywordManager) {
      this.keywordManager = new KeywordManager(this.emitter)
      this.setStatusBarService()
    }
    return this.keywordManager
  },

  toggle (keyword) {
    this.getKeywordManager().toggle(keyword)
  },

  onDidChangeHighlight (fn) {
    return this.emitter.on('did-change-highlight', fn)
  },

  provideQuickHighlight () {
    return {onDidChangeHighlight: this.onDidChangeHighlight.bind(this)}
  },

  setStatusBarService () {
    if (this.statusBarService && this.keywordManager) {
      this.keywordManager.setStatusBarService(this.statusBarService)
    }
  },

  consumeStatusBar (service) {
    this.statusBarService = service
    this.setStatusBarService()
  },

  consumeVim ({getClass, registerCommandsFromSpec}) {
    this.subscriptions.add(
      registerCommandsFromSpec(['QuickHighlight', 'QuickHighlightWord'], {
        prefix: 'vim-mode-plus-user',
        loader: () => require('./load-vmp-commands')(getClass, this.toggle)
      })
    )
  }
}

function getCursorWord (editor) {
  const selection = editor.getLastSelection()
  const selectedText = selection.getText()
  if (selectedText) {
    return selectedText
  } else {
    const cursorPosition = selection.cursor.getBufferPosition()
    selection.selectWord()
    const word = selection.getText()
    selection.cursor.setBufferPosition(cursorPosition)
    return word
  }
}
