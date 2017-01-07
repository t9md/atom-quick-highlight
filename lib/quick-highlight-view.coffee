_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
settings = require './settings'

{
  getVisibleEditors
  matchScope
  collectKeywordRanges
} = require './utils'

module.exports =
  class QuickHighlightView
    rendered: false
    manualDecorationStyle: null

    constructor: (@editor, {@keywordManager, @statusBarManager}) ->
      @markerLayersByKeyword = new Map

      @disposables = new CompositeDisposable

      highlightSelection = null
      @disposables.add settings.observe 'highlightSelectionDelay', (delay) =>
        highlightSelection = _.debounce(@highlightSelection.bind(this), delay)

      @disposables.add settings.observe 'decorate', (decorationStyle) =>
        @manualDecorationStyle = decorationStyle
        @reset()

      @disposables.add(
        @editor.onDidDestroy(@destroy.bind(this))

        # Don't pass function directly since we UPDATE highlightSelection on config change
        @editor.onDidChangeSelectionRange(({selection}) -> highlightSelection(selection))

        @keywordManager.onDidAddKeyword(@addHighlight.bind(this))
        @keywordManager.onDidDeleteKeyword(@deleteHighlight.bind(this))
        @keywordManager.onDidClearKeyword(@clear.bind(this))
        @editor.onDidStopChanging(@reset.bind(this))
      )

    needSelectionHighlight: (selection) ->
      editorElement = @editor.element
      scopes = settings.get('highlightSelectionExcludeScopes')
      switch
        when (not settings.get('highlightSelection'))
            , selection.isEmpty()
            , (scopes.some (scope) -> matchScope(editorElement, scope))
            , not selection.getBufferRange().isSingleLine()
            , selection.getText().length < settings.get('highlightSelectionMinimumLength')
            , /[^\S]/.test(selection.getText())
          false
        else
          true

    highlightSelection: (selection) ->
      @markerLayerForSelectionHighlight?.destroy()
      return unless @needSelectionHighlight(selection)
      if keyword = selection.getText()
        @markerLayerForSelectionHighlight = @highlight(keyword, 'box-selection')

    highlight: (keyword, color) ->
      ranges = collectKeywordRanges(@editor, keyword)
      return null if ranges.length is 0

      markerLayer = @editor.addMarkerLayer()
      decorationOptions = {type: 'highlight', class: "quick-highlight #{color}"}
      @editor.decorateMarkerLayer(markerLayer, decorationOptions)
      markerOptions = {invalidate: 'inside'}
      for range in ranges
        markerLayer.markBufferRange(range, markerOptions)
      markerLayer

    addHighlight: ({keyword, color}) ->
      if not @markerLayersByKeyword.has(keyword)
        if markerLayer = @highlight(keyword, "#{settings.get('decorate')}-#{color}")
          @markerLayersByKeyword.set(keyword, markerLayer)
        @updateStatusBarIfNecesssary()

    deleteHighlight: ({keyword}) ->
      if @markerLayersByKeyword.has(keyword)
        @markerLayersByKeyword.get(keyword).destroy()
        @markerLayersByKeyword.delete(keyword)
        @updateStatusBarIfNecesssary()

    clear: ->
      @markerLayersByKeyword.forEach (markerLayer) ->
        markerLayer.destroy()
      @markerLayersByKeyword.clear()

    render: ->
      {colorsByKeyword} = @keywordManager
      colorsByKeyword.forEach (color, keyword) =>
        @addHighlight({keyword, color})

    reset: ->
      @clear()
      @render()
      @updateStatusBarIfNecesssary()

    refresh: ->
      isVisible = @editor in getVisibleEditors()
      if isVisible is @wasVisible
        @updateStatusBarIfNecesssary()
        return

      if isVisible
        @render()
      else
        @clear()

      @wasVisible = isVisible
      @updateStatusBarIfNecesssary()

    getMarkerCountForKeyword: (keyword) ->
      if @markerLayersByKeyword.has(keyword)
        @markerLayersByKeyword.get(keyword).getMarkerCount()
      else
        0

    updateStatusBarIfNecesssary: ->
      if settings.get('displayCountOnStatusBar') and @editor is atom.workspace.getActiveTextEditor()
        @statusBarManager.clear()
        count = @getMarkerCountForKeyword(@keywordManager.latestKeyword)
        if count > 0
          @statusBarManager.update(count)

    destroy: ->
      @clear()
      @markerLayerForSelectionHighlight?.destroy()
      @disposables.dispose()
