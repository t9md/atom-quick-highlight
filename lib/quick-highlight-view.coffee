_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
settings = require './settings'

{
  getVisibleEditors
  matchScope
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
        @keywordManager.onDidClearKeyword(@clear.bind(this))
        @editor.onDidStopChanging(@reset.bind(this))
      )

    onChangeDecorationStyle: ({newValue}) ->
      @decorationStyle = newValue
      @reset()

    needSelectionHighlight: (selection) ->
      editorElement = @editor.element
      excludeScopes = settings.get('highlightSelectionExcludeScopes')
      switch
        when (not settings.get('highlightSelection'))
            , selection.isEmpty()
            , (excludeScopes.some (scope) -> matchScope(editorElement, scope))
            , not selection.getBufferRange().isSingleLine()
            , selection.getText().length < settings.get('highlightSelectionMinimumLength')
            , (not /\S/.test(selection.getText()))
          false
        else
          true

    highlightSelection: (selection) ->
      @markerLayerForSelectionHighlight?.destroy()
      return unless @needSelectionHighlight(selection)
      if keyword = selection.getText()
        @markerLayerForSelectionHighlight = @highlight(keyword, 'box-selection')

    highlight: (keyword, color) ->
      markerLayer = @editor.addMarkerLayer()
      @editor.decorateMarkerLayer(markerLayer, type: 'highlight', class: "quick-highlight #{color}")
      @editor.scan ///#{_.escapeRegExp(keyword)}///g, ({range}) ->
        markerLayer.markBufferRange(range, invalidate: 'inside')
      markerLayer

    clear: ->
      for keyword, markerLayer of @keywordToMarkerLayer
        markerLayer.destroy()
      @keywordToMarkerLayer = Object.create(null)

    getDiff: ->
      masterKeywords = _.keys(@keywordManager.keywordToColor)
      currentKeywords = _.keys(@keywordToMarkerLayer)
      newKeywords = _.without(masterKeywords, currentKeywords...)
      oldKeywords = _.without(currentKeywords, masterKeywords...)
      if newKeywords.length or oldKeywords.length
        {newKeywords, oldKeywords}
      else
        null

    render: ({newKeywords, oldKeywords}) ->
      # Delete
      for keyword in oldKeywords
        @keywordToMarkerLayer[keyword].destroy()
        delete @keywordToMarkerLayer[keyword]

      # Add
      {keywordToColor} = @keywordManager
      for keyword in newKeywords when color = keywordToColor[keyword]
        @keywordToMarkerLayer[keyword] = @highlight(keyword, "#{@decorationStyle}-#{color}")

    reset: ->
      @clear()
      @refresh()

    refresh: ->
      return unless @editor in getVisibleEditors()

      if diff = @getDiff()
        @render(diff)
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
