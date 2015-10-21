_ = require 'underscore-plus'


MARKER_REGEXP = /^quick-highlight/
# Helpers
# -------------------------
getDecorations = (editor) ->
  editor.getHighlightDecorations().filter (d) ->
    d.properties.class.match MARKER_REGEXP

# Main
# -------------------------
addCustomMatchers = (spec) ->
  spec.addMatchers
    toHaveDecorations: (expected) ->
      editor = @actual
      decos = getDecorations(editor)
      if expected.color?
        pattern = ///#{_.escapeRegExp(expected.color)}///
        decos = decos.filter (d) -> d.properties.class.match pattern

      lengthOK = decos.length is expected.length
      if expected.length is 0
        lengthOK
      else
        textMatches = (expected.text is editor.getTextInBufferRange(d.getMarker().getBufferRange()) for d in decos)
        lengthOK and _.all(textMatches)

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
  beforeEach ->
    addCustomMatchers(this)

    workspaceElement = atom.views.getView(atom.workspace)
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
      editorElement = atom.views.getView(editor)
      editor.setCursorBufferPosition([0, 0])
      activationPromise = atom.packages.activatePackage("quick-highlight").then (pack) ->
        main = pack.mainModule
      atom.commands.dispatch(editorElement, 'quick-highlight:toggle')

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

      atom.commands.dispatch(editorElement, 'quick-highlight:toggle')

      expect(main.keywords.has('orange')).toBe false
      expect(main.keywords.has('apple')).toBe false
      expect(editor).lengthOfDecorationsToBe 0

    it "can decorate multiple keyword simultaneously", ->
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false
      expect(editor).lengthOfDecorationsToBe 3
      editor.setCursorScreenPosition [1, 12]
      atom.commands.dispatch(editorElement, 'quick-highlight:toggle')

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
      atom.commands.dispatch(editorElement, 'quick-highlight:toggle')

      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe true
      expect(editor).lengthOfDecorationsToBe 6

      atom.commands.dispatch(editorElement, 'quick-highlight:clear')
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
          editor2Element = atom.views.getView(editor2)
          editor2.setCursorBufferPosition [0, 0]

      runs ->
        expect(editor2).toBeActiveEditor()
        atom.commands.dispatch(editorElement, 'quick-highlight:clear')
        expect(editor).lengthOfDecorationsToBe 0
        expect(main.decorationsByEditor.has(editor)).toBe false
        expect(editor2).lengthOfDecorationsToBe 0
        expect(main.decorationsByEditor.has(editor2)).toBe false

    it "can decorate keyword across visible editors", ->
      atom.commands.dispatch(editor2Element, 'quick-highlight:toggle')
      expect(main.keywords.has('orange')).toBe true
      expect(main.keywords.has('apple')).toBe false

      expect(editor).toHaveDecorations color: '01', length: 3, text: 'orange'
      expect(editor2).toHaveDecorations color: '01', length: 3, text: 'orange'

    it "decorate keywords when new editor was opened", ->
      atom.commands.dispatch(editor2Element, 'quick-highlight:toggle')
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

  describe "editor is scrollable", ->
    [editor4, editorElement4] = []
    lineHeightPx = 10
    rowsPerPage = 5
    scroll = (editor) ->
      editor.setScrollTop(editor.getScrollTop() + editor.getHeight())

    beforeEach ->
      runs ->
        atom.commands.dispatch(editorElement, 'quick-highlight:clear')

      pathSample4 = atom.project.resolvePath "sample-4"

      waitsForPromise ->
        atom.workspace.open(pathSample4).then (e) ->
          editor4 = e
          editor4.setLineHeightInPixels(lineHeightPx)
          editor4.setHeight(rowsPerPage * lineHeightPx)
          editorElement4 = atom.views.getView(editor4)

      runs ->
        editor4.setCursorScreenPosition [1, 0]
        atom.commands.dispatch(editorElement4, 'quick-highlight:toggle')
        editor4.setCursorScreenPosition [3, 0]
        atom.commands.dispatch(editorElement4, 'quick-highlight:toggle')
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
          atom.commands.dispatch(editorElement4, 'quick-highlight:clear')

          editor4.setCursorScreenPosition [1, 0]
          atom.commands.dispatch(editorElement4, 'quick-highlight:toggle')
          expect(editor4).toHaveDecorations color: '01', length: 1, text: 'orange'
          container = workspaceElement.querySelector('#status-bar-quick-highlight')
          span = container.querySelector('span')

      it 'display latest highlighted count on statusbar', ->
        expect(container.style.display).toBe 'inline-block'
        expect(span.textContent).toBe '3'

        editor4.setCursorScreenPosition [3, 0]
        atom.commands.dispatch(editorElement4, 'quick-highlight:toggle')
        expect(editor4).toHaveDecorations color: '02', length: 1, text: 'apple'
        expect(container.style.display).toBe 'inline-block'
        expect(span.textContent).toBe '5'

      it 'hide count when decoration cleared', ->
        atom.commands.dispatch(editorElement4, 'quick-highlight:toggle')
        expect(editor4).lengthOfDecorationsToBe 0
        expect(container.style.display).toBe 'none'
