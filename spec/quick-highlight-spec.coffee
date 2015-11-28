_ = require 'underscore-plus'

MARKER_REGEXP = /^quick-highlight/
# Helpers
# -------------------------
getDecorations = (editor) ->
  editor.getHighlightDecorations().filter (d) ->
    d.properties.class.match MARKER_REGEXP

getView = (model) ->
  atom.views.getView(model)

getVisibleBufferRowRange = (editor) ->
  getView(editor).getVisibleRowRange().map (row) ->
    editor.bufferRowForScreenRow row

setConfig = (name, value) ->
  atom.config.set("quick-highlight.#{name}", value)

# Main
# -------------------------
addCustomMatchers = (spec) ->
  getNotText = ->
    if spec.isNot then " not" else ""

  spec.addMatchers
    toHaveDecorations: (expected) ->
      notText = getNotText()
      editor = @actual
      decos = getDecorations(editor)
      if expected.color?
        pattern = ///#{_.escapeRegExp(expected.color)}///
        decos = decos.filter (d) -> d.properties.class.match pattern

      lengthOK = decos.length is expected.length
      if expected.length is 0
        lengthOK
      else
        texts = (editor.getTextInBufferRange(d.getMarker().getBufferRange()) for d in decos)
        this.message = -> "Expected #{jasmine.pp(texts)}, length: #{texts.length} to#{notText} #{jasmine.pp(expected)}"
        lengthOK and _.all(texts, (text) -> text is expected.text)

    lengthOfDecorationsToBe: (expected) ->
      getDecorations(@actual).length is expected

    toHaveAllMarkerDestoyed: (expected) ->
      editor = @actual
      results = (d.getMarker().isDestroyed() for d in getDecorations(editor))
      _.all results

    toBeActiveEditor: ->
      @actual is atom.workspace.getActiveTextEditor()

describe "quick-highlight", ->
  [editor, editorContent, editorElement, main, workspaceElement, pathSample1, pathSample2] = []

  dispatchCommand = (command, {element}={}) ->
    element ?= editorElement
    atom.commands.dispatch(element, command)

  beforeEach ->
    addCustomMatchers(this)
    spyOn(_._, "now").andCallFake -> window.now

    workspaceElement = getView(atom.workspace)
    jasmine.attachToDOM workspaceElement
    activationPromise = null

    editorContent = """
      orange
          apple
      orange
          apple
      orange
          apple
      """

    waitsForPromise ->
      atom.workspace.open('sample-1').then (e) ->
        editor = e
        editor.setText editorContent

    runs ->
      editorElement = getView(editor)
      editor.setCursorBufferPosition([0, 0])
      activationPromise = atom.packages.activatePackage("quick-highlight").then (pack) ->
        main = pack.mainModule
      dispatchCommand('quick-highlight:toggle')

    waitsForPromise ->
      activationPromise

  describe "quick-highlight:toggle", ->
    it "decorate keyword under cursor", ->
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false
      expect(editor).toHaveDecorations length: 3, color: '01', text: 'orange'

    it "remove decoration when if already decorated", ->
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false
      expect(editor).lengthOfDecorationsToBe 3
      dispatchCommand('quick-highlight:toggle')

      expect(main.keywords.has('orange')).toBe false
      expect(main.keywords.has('apple')).toBe false
      expect(editor).lengthOfDecorationsToBe 0

    it "can decorate multiple keyword simultaneously", ->
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false
      expect(editor).lengthOfDecorationsToBe 3
      editor.setCursorScreenPosition [1, 12]
      dispatchCommand('quick-highlight:toggle')

      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe true
      expect(editor).lengthOfDecorationsToBe 6
      expect(editor).toHaveDecorations color: '01', length: 3, text: 'orange'
      expect(editor).toHaveDecorations color: '02', length: 3, text: 'apple'

    it "destroy decoration when editor is destroyed", ->
      expect(main.keywords.has('orange')).toBe true
      expect(editor).lengthOfDecorationsToBe 3
      editor.destroy()
      expect(editor).toHaveAllMarkerDestoyed()

  describe "quick-highlight:clear", ->
    it "clear all decorations", ->
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false
      expect(editor).lengthOfDecorationsToBe 3
      editor.setCursorScreenPosition [1, 12]
      dispatchCommand('quick-highlight:toggle')

      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe true
      expect(editor).lengthOfDecorationsToBe 6

      dispatchCommand('quick-highlight:clear')
      expect(editor).lengthOfDecorationsToBe 0
      expect(main.keywords.has('orange')).toBe false
      expect(main.keywords.has('apple')).toBe false
      expect(editor).toHaveAllMarkerDestoyed()
      expect(main.decorationsByEditor.has(editor)).toBe false

  describe "multiple editors is displayed", ->
    [editor2, editor2Element] = []
    beforeEach ->
      waitsForPromise ->
        atom.workspace.open('sample-2', {split: 'right'}).then (e) ->
          editor2 = e
          editor2.setText editorContent
          editor2Element = getView(editor2)
          editor2.setCursorBufferPosition [0, 0]

      runs ->
        expect(editor2).toBeActiveEditor()
        dispatchCommand('quick-highlight:clear')
        expect(editor).lengthOfDecorationsToBe 0
        expect(main.decorationsByEditor.has(editor)).toBe false
        expect(editor2).lengthOfDecorationsToBe 0
        expect(main.decorationsByEditor.has(editor2)).toBe false

    it "can decorate keyword across visible editors", ->
      dispatchCommand('quick-highlight:toggle', editor2Element)
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false
      expect(editor).toHaveDecorations color: '01', length: 3, text: 'orange'
      expect(editor2).toHaveDecorations color: '01', length: 3, text: 'orange'

    it "clear selectionDecorations when activePane changed", ->
      dispatchCommand('core:select-right', element: editor2Element)
      dispatchCommand('core:select-right', element: editor2Element)
      advanceClock(150)
      expect(editor2.getSelectedText()).toBe "or"
      expect(getDecorations(editor2)).toHaveLength 3
      dispatchCommand('window:focus-next-pane', element: editor2Element)
      expect(editor).toBeActiveEditor()
      expect(getDecorations(editor2)).toHaveLength 0

    it "decorate keywords when new editor was opened", ->
      dispatchCommand('quick-highlight:toggle', editor2Element)
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false

      editor3 = null
      pathSample3 = atom.project.resolvePath "sample-3"

      waitsForPromise ->
        atom.workspace.open(pathSample3, {split: 'right'}).then (e) ->
          editor3 = e

      runs ->
        expect(editor).toHaveDecorations color: '01', length: 3, text: 'orange'
        expect(editor2).toHaveDecorations color: '01', length: 3, text: 'orange'
        expect(editor3).toHaveDecorations color: '01', length: 3, text: 'orange'

  describe "selection changed when highlightSelection", ->
    beforeEach ->
      dispatchCommand('quick-highlight:clear')
      expect(editor).lengthOfDecorationsToBe 0
      expect(main.keywords.has('orange')).toBe false
      expect(main.keywords.has('apple')).toBe false
      expect(editor).toHaveAllMarkerDestoyed()
      expect(main.decorationsByEditor.has(editor)).toBe false

    it "decorate selected keyword", ->
      dispatchCommand('editor:select-word')
      advanceClock(150)
      expect(editor).toHaveDecorations length: 3, color: 'selection', text: 'orange'

    it "clear decoration when selection is cleared", ->
      dispatchCommand('editor:select-word')
      advanceClock(150)
      expect(editor).toHaveDecorations length: 3, color: 'selection', text: 'orange'
      editor.clearSelections()
      advanceClock(150)
      expect(getDecorations(editor)).toHaveLength 0

    it "won't decorate selectedText length is less than highlightSelectionMinimumLength", ->
      setConfig('highlightSelectionMinimumLength', 3)
      dispatchCommand('core:select-right')
      advanceClock(150)
      expect(editor.getSelectedText()).toBe "o"
      expect(getDecorations(editor)).toHaveLength 0
      dispatchCommand('core:select-right')
      advanceClock(150)
      expect(editor.getSelectedText()).toBe "or"
      expect(getDecorations(editor)).toHaveLength 0
      dispatchCommand('core:select-right')
      advanceClock(150)
      expect(editor.getSelectedText()).toBe "ora"
      expect(editor).toHaveDecorations color: 'selection', length: 3, text: 'ora'

    it "won't decorate when selection is all white space", ->
      editor.setCursorBufferPosition([1, 0])
      dispatchCommand('core:select-right')
      dispatchCommand('core:select-right')
      advanceClock(150)
      {start, end} = editor.getLastSelection().getBufferRange()
      expect(start).toEqual [1, 0]
      expect(end).toEqual [1, 4]
      expect(getDecorations(editor)).toHaveLength 0

    it "won't decorate when selection is multi-line", ->
      editor.setCursorBufferPosition([1, 0])
      dispatchCommand('core:select-down')
      advanceClock(150)
      expect(editor.getLastSelection().isEmpty()).toBe false
      expect(getDecorations(editor)).toHaveLength 0

    describe "when highlightSelectionExcludeUnique is set", ->
      beforeEach ->
        setConfig('highlightSelectionExcludeUnique', true)
        editor.setText """
          orange not
          orange
          """

      it "won't decorate when only one occurence of selection is found", ->
        dispatchCommand('editor:select-to-end-of-line')
        expect(editor.getSelectedText()).toBe 'orange not'
        advanceClock(150)
        expect(getDecorations(editor)).toHaveLength 0

      it "will decorate multiple occurences of selection", ->
        dispatchCommand('editor:select-word')
        advanceClock(150)
        expect(editor).toHaveDecorations length: 2, color: 'selection', text: 'orange'

    it "won't decorate when highlightSelection is disabled", ->
      setConfig('highlightSelection', false)
      dispatchCommand('editor:select-word')
      advanceClock(150)
      expect(editor.getSelectedText()).toBe "orange"
      expect(getDecorations(editor)).toHaveLength 0

    describe "highlightSelectionExcludeScopes", ->
      beforeEach ->
        setConfig('highlightSelectionExcludeScopes', [
            'foo.bar',
            'hoge',
          ])

      it "won't decorate when editor have specified scope case-1", ->
        editorElement.classList.add 'foo', 'bar'
        dispatchCommand('editor:select-word')
        advanceClock(150)
        expect(editor.getSelectedText()).toBe "orange"
        expect(getDecorations(editor)).toHaveLength 0

      it "won't decorate when editor have specified scope case-2", ->
        editorElement.classList.add 'hoge'
        dispatchCommand('editor:select-word')
        advanceClock(150)
        expect(editor.getSelectedText()).toBe "orange"
        expect(getDecorations(editor)).toHaveLength 0

  describe "editor is scrolled", ->
    [editor4, editorElement4] = []
    lineHeightPx = 10
    rowsPerPage = 10
    scroll = (editor) ->
      el = getView(editor)
      amountInPixel = editor.getRowsPerPage() * editor.getLineHeightInPixels()
      el.setScrollTop(el.getScrollTop() + amountInPixel)

    beforeEach ->
      runs ->
        dispatchCommand('quick-highlight:clear')

      pathSample4 = atom.project.resolvePath "sample-4"

      waitsForPromise ->
        atom.workspace.open(pathSample4).then (e) ->
          editor4 = e
          editorElement4 = getView(editor4)
          editorElement4.setHeight(rowsPerPage * lineHeightPx)
          editorElement4.style.font = "12px monospace"
          editorElement4.style.lineHeight = "#{lineHeightPx}px"
          atom.views.performDocumentPoll()

      runs ->
        editor4.setCursorScreenPosition [1, 0]
        dispatchCommand('quick-highlight:toggle', element: editorElement4)
        editor4.setCursorBufferPosition [3, 0]
        dispatchCommand('quick-highlight:toggle', element: editorElement4)
        expect(main.keywords.has('orange')).toBe true
        expect(main.keywords.has('apple')).toBe true

    describe "decorate only visible area", ->
      it "update decoration on scroll", ->
        expect(editor4).toHaveDecorations color: '01', length: 1, text: 'orange'
        expect(editor4).toHaveDecorations color: '02', length: 1, text: 'apple'
        scroll(editor4)
        expect(editor4).toHaveDecorations color: '01', length: 2, text: 'orange'
        expect(editor4).toHaveDecorations color: '02', length: 1, text: 'apple'
        scroll(editor4)
        expect(editor4).toHaveDecorations color: '01', length: 0
        expect(editor4).toHaveDecorations color: '02', length: 3, text: 'apple'

    describe "::getCountForKeyword", ->
      it 'return count of keyword within editor', ->
        expect(main.getCountForKeyword(editor4, 'orange')).toBe 3
        expect(main.getCountForKeyword(editor4, 'apple')).toBe 5

    describe "displayCountOnStatusBar", ->
      [container, span] = []
      beforeEach ->
        waitsForPromise ->
          atom.packages.activatePackage("status-bar")

        waitsFor ->
          main.statusBarManager.tile?

        runs ->
          dispatchCommand('quick-highlight:clear', element: editorElement4)
          editor4.setCursorScreenPosition [1, 0]
          dispatchCommand('quick-highlight:toggle', element: editorElement4)
          expect(editor4).toHaveDecorations color: '01', length: 1, text: 'orange'
          container = workspaceElement.querySelector('#status-bar-quick-highlight')
          span = container.querySelector('span')

      it 'display latest highlighted count on statusbar', ->
        expect(container.style.display).toBe 'inline-block'
        expect(span.textContent).toBe '3'

        editor4.setCursorScreenPosition [3, 0]
        dispatchCommand('quick-highlight:toggle', element: editorElement4)
        expect(editor4).toHaveDecorations color: '02', length: 1, text: 'apple'
        expect(container.style.display).toBe 'inline-block'
        expect(span.textContent).toBe '5'

      it 'hide count when decoration cleared', ->
        dispatchCommand('quick-highlight:toggle', element: editorElement4)
        expect(editor4).lengthOfDecorationsToBe 0
        expect(container.style.display).toBe 'none'
