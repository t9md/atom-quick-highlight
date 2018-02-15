const {Emitter} = require('atom')
const QuickHighlightView = require('./quick-highlight-view')
const StatusBarManager = require('./status-bar-manager')

const Colors = {
  colorNumbers: ['01', '02', '03', '04', '05', '06', '07'],
  next () {
    this.index = (this.index + 1) % this.colorNumbers.length
    return this.colorNumbers[this.index]
  },
  reset () {
    this.index = -1
  }
}

module.exports = class KeywordManager {
  onDidChangeKeyword (fn) { return this.emitter.on('did-change-keyword', fn) } // prettier-ignore
  emitDidChangeKeyword () { this.emitter.emit('did-change-keyword') } // prettier-ignore
  onDidClearKeyword (fn) { return this.emitter.on('did-clear-keyword', fn) } // prettier-ignore
  emitDidClearKeyword () { this.emitter.emit('did-clear-keyword') } // prettier-ignore

  constructor (mainEmitter, statusBarService) {
    this.reset()
    this.latestKeyword = null

    this.emitter = new Emitter()
    this.viewByEditor = new Map()
    this.statusBarManager = new StatusBarManager()

    if (statusBarService) {
      this.statusBarManager.initialize(statusBarService)
      this.statusBarManager.attach()
    }

    this.editorSubscription = atom.workspace.observeTextEditors(editor => {
      const view = new QuickHighlightView(editor, {
        keywordManager: this,
        statusBarManager: this.statusBarManager,
        emitter: mainEmitter
      })
      this.viewByEditor.set(editor, view)
    })
  }

  reset () {
    this.colorByKeyword = new Map()
    Colors.reset()
  }

  getCursorWord (editor) {
    const selection = editor.getLastSelection()
    const cursorPosition = selection.cursor.getBufferPosition()
    selection.selectWord()
    const word = selection.getText()
    selection.cursor.setBufferPosition(cursorPosition)
    return word
  }

  toggle (keyword) {
    if (!keyword) {
      const editor = atom.workspace.getActiveTextEditor()
      keyword = editor.getSelectedText() || this.getCursorWord(editor)
    }
    if (this.colorByKeyword.has(keyword)) {
      this.colorByKeyword.delete(keyword)
    } else {
      this.colorByKeyword.set(keyword, Colors.next())
      this.latestKeyword = keyword
    }

    this.emitDidChangeKeyword()
  }

  getColorForKeyword (keyword) {
    return this.colorByKeyword.get(keyword)
  }

  getKeywords () {
    return [...this.colorByKeyword.keys()]
  }

  clear () {
    this.reset()
    this.emitDidClearKeyword()
  }

  destroy () {
    this.viewByEditor.forEach(view => view.destroy())
    this.viewByEditor.clear()
    this.viewByEditor = null

    this.editorSubscription.dispose()
    this.editorSubscription = null

    this.statusBarManager.detach()
    this.statusBarManager = null
  }
}
