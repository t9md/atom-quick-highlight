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

    constructor: (@editor, {@keywordManager, @statusBarManager}) ->
      @keywordToMarkerLayer = Object.create(null)
      @decorationStyle = settings.get('decorate')

      @disposables = new CompositeDisposable

      highlightSelection = null
      updateHighlightSelection = (delay) =>
        highlightSelection = _.debounce(@highlightSelection.bind(this), delay)

      @disposables.add(
        settings.observe('highlightSelectionDelay', updateHighlightSelection)
        settings.onDidChange('decorate', @onChangeDecorationStyle.bind(this))
        @editor.onDidDestroy(@destroy.bind(this))

        # Don't pass function directly since we UPDATE highlightSelection on config change
        @editor.onDidChangeSelectionRange(({selection}) -> highlightSelection(selection))

        @keywordManager.onDidChangeKeyword(@refresh.bind(this))
        @editor.onDidStopChanging(@reset.bind(this))
      )

    onChangeDecorationStyle: ({newValue}) ->
      @decorationStyle = newValue
      @reset()

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

    clear: ->
      for keyword, markerLayer of @keywordToMarkerLayer
        markerLayer.destroy()
      @keywordToMarkerLayer = Object.create(null)

    render: ->
      {keywordToColor} = @keywordManager
      masterKeywords = _.keys(keywordToColor)
      currentKeywords = _.keys(@keywordToMarkerLayer)
      keywordsToAdd = _.without(masterKeywords, currentKeywords...)
      keywordsToDelete = _.without(currentKeywords, masterKeywords...)

      # Delete
      for keyword in keywordsToDelete
        @keywordToMarkerLayer[keyword].destroy()
        delete @keywordToMarkerLayer[keyword]

      # Add
      for keyword in keywordsToAdd when color = keywordToColor[keyword]
        if markerLayer = @highlight(keyword, "#{@decorationStyle}-#{color}")
          @keywordToMarkerLayer[keyword] = markerLayer

    reset: ->
      @clear()
      @refresh()

    refresh: ->
      isVisible = @editor in getVisibleEditors()
      if isVisible
        @render()
      else
        @clear()
      @updateStatusBarIfNecesssary()

    updateStatusBarIfNecesssary: ->
      if settings.get('displayCountOnStatusBar') and @editor is atom.workspace.getActiveTextEditor()
        @statusBarManager.clear()
        keyword = @keywordManager.latestKeyword
        count = @keywordToMarkerLayer[keyword]?.getMarkerCount() ? 0
        if count > 0
          @statusBarManager.update(count)

    destroy: ->
      @clear()
      @markerLayerForSelectionHighlight?.destroy()
      @disposables.dispose()
