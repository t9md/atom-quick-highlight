_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
settings = require './settings'

{
  getVisibleEditors
  matchScope
} = require './utils'

module.exports =
  class QuickHighlightView
    constructor: (@editor, @main) ->
      @editorElement = @editor.element
      @markerLayers = []

      @disposables = new CompositeDisposable
      @disposables.add(
        @editor.onDidDestroy(@destroy.bind(this))
        @editor.onDidChangeSelectionRange(@highlightSelection.bind(this))
        @main.onDidChangeKeyword(@refresh.bind(this))
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

    highlightSelection: ({selection}) ->
      @markerLayerForSelectionHighlight?.destroy()
      return unless @needSelectionHighlight(selection)
      if keyword = selection.getText()
        @markerLayerForSelectionHighlight = @highlight(keyword, 'box-selection')

    highlight: (keyword, color) ->
      markerLayer = @editor.addMarkerLayer()
      decorationStyle = settings.get('decorate')
      if color is 'box-selection'
        colorName = color
      else
        colorName = "#{decorationStyle}-#{color}"
      decorationOptions = {type: 'highlight', class: "quick-highlight #{colorName}"}
      @editor.decorateMarkerLayer(markerLayer, decorationOptions)

      markerOptions = {invalidate: 'inside'}
      pattern = ///#{_.escapeRegExp(keyword)}///g
      @editor.scan pattern, ({range, matchText}) ->
        markerLayer.markBufferRange(range, markerOptions)
      markerLayer

    refresh: ({colorsByKeyword}) ->
      decorationStyle = settings.get('decorate')
      @clear()
      colorsByKeyword.forEach (color, keyword) =>
        @markerLayers.push(@highlight(keyword, color))

    isVisible: ->
      @editor in getVisibleEditors()

    clear: ->
      for markerLayer in @markerLayers
        markerLayer.destroy()

    destroy: ->
      @clear()
      @markerLayerForSelectionHighlight?.destroy()
      @disposable.dispose()
