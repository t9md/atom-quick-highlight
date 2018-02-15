const _ = require('underscore-plus')
const {CompositeDisposable} = require('atom')

function matchScopes ({classList}, scopes = []) {
  return scopes.some(scope => scope.split('.').every(name => classList.contains(name)))
}

function getConfig (name) {
  return atom.config.get(`quick-highlight.${name}`)
}

function getVisibleEditors () {
  return atom.workspace
    .getPanes()
    .map(pane => pane.getActiveEditor())
    .filter(v => v)
}

function isVisibleEditor (editor) {
  return getVisibleEditors().includes(editor)
}

function isActiveEditor (editor) {
  return atom.workspace.getActiveTextEditor() === editor
}

// - Refresh onDidChangeActivePaneItem
// - But dont't refresh invisible editor
// - Update statusbar count on activeEditor was changed
// - Clear marker for invisible editor?: Decide to skip to avoid clere/re-render.
// - Update only keyword added/remove: Achived by diffing.
class QuickHighlightView {
  static initClass () { this.viewByEditor = new Map() } // prettier-ignore
  static register (view) { this.viewByEditor.set(view.editor, view) } // prettier-ignore
  static unregister (view) { this.viewByEditor.delete(view.editor) } // prettier-ignore
  static destroyAll () { this.viewByEditor.forEach(view => view.destroy()) } // prettier-ignore
  static clearAll () { this.viewByEditor.forEach(view => view.clear()) } // prettier-ignore

  static refreshVisibles () {
    const editors = getVisibleEditors()
    this.viewByEditor.forEach(view => {
      if (editors.includes(view.editor)) {
        view.refresh()
      }
    })
  }

  constructor (editor, {keywordManager, statusBarManager, emitter}) {
    this.editor = editor
    this.keywordManager = keywordManager
    this.statusBarManager = statusBarManager
    this.emitter = emitter
    this.markerLayerByKeyword = new Map()

    this.highlightSelection = this.highlightSelection.bind(this)
    let highlightSelection
    this.disposables = new CompositeDisposable(
      atom.config.observe('quick-highlight.highlightSelectionDelay', delay => {
        highlightSelection = _.debounce(this.highlightSelection, delay)
      }),
      this.editor.onDidDestroy(() => this.destroy()),
      this.editor.onDidChangeSelectionRange(({selection}) => {
        if (selection.isEmpty()) {
          this.clearSelectionHighlight()
        } else {
          highlightSelection(selection)
        }
      }),
      this.editor.onDidStopChanging(() => {
        this.clear()
        if (isVisibleEditor(this.editor)) {
          this.refresh()
        }
      })
    )

    QuickHighlightView.register(this)
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
    const masterKeywords = this.keywordManager.getKeywords()
    const currentKeywords = [...this.markerLayerByKeyword.keys()]
    const newKeywords = _.without(masterKeywords, ...currentKeywords)
    const oldKeywords = _.without(currentKeywords, ...masterKeywords)

    if (newKeywords.length || oldKeywords.length) {
      return {newKeywords, oldKeywords}
    }
  }

  render ({newKeywords, oldKeywords}) {
    // Delete
    for (const keyword of oldKeywords) {
      this.markerLayerByKeyword.get(keyword).destroy()
      this.markerLayerByKeyword.delete(keyword)
    }

    // Add
    for (const keyword of newKeywords) {
      const color = this.keywordManager.getColorForKeyword(keyword)
      if (color) {
        const decorationColor = atom.config.get('quick-highlight.decorate')
        const markerLayer = this.highlight(keyword, `${decorationColor}-${color}`)
        this.markerLayerByKeyword.set(keyword, markerLayer)
      }
    }
  }

  clear () {
    this.markerLayerByKeyword.forEach(layer => layer.destroy())
    this.markerLayerByKeyword.clear()
  }

  reset () {
    this.clear()
    this.refresh()
  }

  refresh () {
    const diff = this.getDiff()
    if (diff) {
      this.render(diff)
    }
    this.updateStatusBarIfNecesssary()
  }

  updateStatusBarIfNecesssary () {
    if (getConfig('displayCountOnStatusBar') && isActiveEditor(this.editor)) {
      this.statusBarManager.clear()
      const keyword = this.keywordManager.latestKeyword

      const layer = this.markerLayerByKeyword.get(keyword)
      const count = layer ? layer.getMarkerCount() : 0
      if (count) this.statusBarManager.update(count)
    }
  }

  destroy () {
    this.disposables.dispose()
    this.clear()
    this.clearSelectionHighlight()
    QuickHighlightView.unregister(this)
  }
}

QuickHighlightView.initClass()
module.exports = QuickHighlightView
