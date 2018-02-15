const _ = require('underscore-plus')
const {CompositeDisposable} = require('atom')

function matchScopes ({classList}, scopes = []) {
  return scopes.some(scope => scope.split('.').every(name => classList.contains(name)))
}

function getConfig (name) {
  return atom.config.get(`quick-highlight.${name}`)
}

// - Refresh onDidChangeActivePaneItem
// - But dont't refresh invisible editor
// - Update statusbar count on activeEditor was changed
// - Clear marker for invisible editor?: Decide to skip to avoid clere/re-render.
// - Update only keyword added/remove: Achived by diffing.
module.exports = class QuickHighlightView {
  constructor (editor, {keywordManager, statusBarManager, emitter}) {
    this.editor = editor
    this.keywordManager = keywordManager
    this.statusBarManager = statusBarManager
    this.emitter = emitter
    this.keywordToMarkerLayer = Object.create(null)

    this.highlightSelection = this.highlightSelection.bind(this)
    let highlightSelection = null
    this.disposables = new CompositeDisposable(
      atom.config.observe('quick-highlight.highlightSelectionDelay', delay => {
        highlightSelection = _.debounce(this.highlightSelection, delay)
      }),
      atom.config.observe('quick-highlight.decorate', newValue => {
        this.decorationStyle = newValue
        this.reset()
      }),
      this.editor.onDidDestroy(() => this.destroy()),
      this.editor.onDidChangeSelectionRange(({selection}) => {
        if (selection.isEmpty()) this.clearSelectionHighlight()
        else highlightSelection(selection)
      }),
      atom.workspace.onDidChangeActivePaneItem(() => this.refresh()),
      this.keywordManager.onDidChangeKeyword(() => this.refresh()),
      this.keywordManager.onDidClearKeyword(() => this.clear()),
      this.editor.onDidStopChanging(() => this.reset())
    )
  }

  needSelectionHighlight (text) {
    return (
      getConfig('highlightSelection') &&
      !matchScopes(this.editor.element, getConfig('highlightSelectionExcludeScopes')) &&
      text.length >= getConfig('highlightSelectionMinimumLength') &&
      !/\n/.test(text) &&
      /\S/.test(text)
    )
  }

  highlightSelection (selection) {
    this.clearSelectionHighlight()
    const keyword = selection.getText()
    if (this.needSelectionHighlight(keyword)) {
      this.markerLayerForSelectionHighlight = this.highlight(keyword, 'box-selection')
    }
  }

  clearSelectionHighlight () {
    if (this.markerLayerForSelectionHighlight) this.markerLayerForSelectionHighlight.destroy()
    this.markerLayerForSelectionHighlight = null
  }

  highlight (keyword, color) {
    const markerLayer = this.editor.addMarkerLayer()
    this.editor.decorateMarkerLayer(markerLayer, {type: 'highlight', class: `quick-highlight ${color}`})
    const regex = new RegExp(`${_.escapeRegExp(keyword)}`, 'g')
    this.editor.scan(regex, ({range}) => markerLayer.markBufferRange(range, {invalidate: 'inside'}))

    if (markerLayer.getMarkerCount()) {
      this.emitter.emit('did-change-highlight', {
        editor: this.editor,
        markers: markerLayer.getMarkers(),
        color: color
      })
    }
    return markerLayer
  }

  getDiff () {
    const masterKeywords = _.keys(this.keywordManager.keywordToColor)
    const currentKeywords = _.keys(this.keywordToMarkerLayer)
    const newKeywords = _.without(masterKeywords, ...currentKeywords)
    const oldKeywords = _.without(currentKeywords, ...masterKeywords)

    return newKeywords.length || oldKeywords.length ? {newKeywords, oldKeywords} : null
  }

  render ({newKeywords, oldKeywords}) {
    // Delete
    for (const keyword of oldKeywords) {
      this.keywordToMarkerLayer[keyword].destroy()
      delete this.keywordToMarkerLayer[keyword]
    }

    // Add
    const {keywordToColor} = this.keywordManager
    for (const keyword of newKeywords) {
      const color = keywordToColor[keyword]
      if (color) {
        this.keywordToMarkerLayer[keyword] = this.highlight(keyword, `${this.decorationStyle}-${color}`)
      }
    }
  }

  clear () {
    for (const keyword in this.keywordToMarkerLayer) {
      this.keywordToMarkerLayer[keyword].destroy()
    }
    this.keywordToMarkerLayer = Object.create(null)
  }

  reset () {
    this.clear()
    this.refresh()
  }

  refresh () {
    const visibleEditors = atom.workspace
      .getPanes()
      .map(pane => pane.getActiveEditor())
      .filter(editor => editor)
    if (!visibleEditors.includes(this.editor)) return

    const diff = this.getDiff()
    if (diff) this.render(diff)

    this.updateStatusBarIfNecesssary()
  }

  updateStatusBarIfNecesssary () {
    if (!getConfig('displayCountOnStatusBar') || this.editor !== atom.workspace.getActiveTextEditor()) {
      return
    }

    this.statusBarManager.clear()
    const keyword = this.keywordManager.latestKeyword

    const markerLayer = this.keywordToMarkerLayer[keyword]
    const count = markerLayer ? markerLayer.getMarkerCount() : 0
    if (count) this.statusBarManager.update(count)
  }

  destroy () {
    this.clear()
    this.clearSelectionHighlight()
    this.disposables.dispose()
  }
}
