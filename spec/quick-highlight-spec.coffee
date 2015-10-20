_ = require 'underscore-plus'

addCustomMatchers = (spec) ->
  spec.addMatchers
    toHaveDecorations: (expected) ->
      editor = @actual
      decos = (d for d in editor.getHighlightDecorations() when d.properties.class.match /^quick-highlight/)
      if expected.color?
        pattern = ///#{_.escapeRegExp(expected.color)}///
        decos = (d for d in decos when d.properties.class.match pattern)

      lengthOK = decos.length is expected.length
      if expected.length is 0
        lengthOK
      else
        textRults = (expected.text is editor.getTextInBufferRange(d.getMarker().getBufferRange()) for d in decos)
        lengthOK and _.all(textRults)

    lengthOfDecorationsToBe: (expected) ->
      editor = @actual
      decos = (d for d in editor.getHighlightDecorations() when d.properties.class.match /^quick-highlight/)
      decos.length is expected

describe "quick-highlight", ->
  [editor, editorContent, editorElement, main, pathSample1, pathSample2, workspaceElement] = []
  beforeEach ->
    addCustomMatchers(this)

    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)
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

  getDecorations = (editor) ->
    (d for d in editor.getHighlightDecorations() when d.properties.class.match /^quick-highlight/)

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
      for d in getDecorations(editor)
        expect(d.getMarker().isDestroyed()).toBe true
      expect(main.decorationsByEditor.has(editor)).toBe false

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
      for d in getDecorations(editor)
        expect(d.getMarker().isDestroyed()).toBe true
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
        activeEditor = atom.workspace.getActiveTextEditor()
        expect(activeEditor.getURI() is editor2.getURI()).toBe true
        atom.commands.dispatch(editorElement, 'quick-highlight:clear')
        expect(editor).lengthOfDecorationsToBe 0
        expect(editor2).lengthOfDecorationsToBe 0
        expect(main.decorationsByEditor.has(editor)).toBe false
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

  describe "editor was scrolled", ->
    [lineHeightPx, rowsPerPage] = []
    scroll = (editor) ->
      editor.setScrollTop(editor.getScrollTop() + editor.getHeight())

    beforeEach ->
      pathSample4 = atom.project.resolvePath "sample-4"

      waitsForPromise ->
        atom.workspace.open(pathSample4).then (e) ->
          editor = e
          editorElement = atom.views.getView(editor)

      runs ->
        lineHeightPx = 10
        rowsPerPage = 5
        editor.setLineHeightInPixels(lineHeightPx)
        editor.setHeight(rowsPerPage * lineHeightPx) # 5 rows

        atom.commands.dispatch(editorElement, 'quick-highlight:clear')
        expect(editor).lengthOfDecorationsToBe 0

        editor.setCursorScreenPosition [1, 0]
        atom.commands.dispatch(editorElement, 'quick-highlight:toggle')
        editor.setCursorScreenPosition [3, 0]
        atom.commands.dispatch(editorElement, 'quick-highlight:toggle')
        expect(main.keywords.has('orange')).toBe true
        expect(main.keywords.has('apple')).toBe true

    it "update decoration on scroll", ->
      expect(editor).toHaveDecorations color: '01', length: 1, text: 'orange'
      expect(editor).toHaveDecorations color: '02', length: 1, text: 'apple'
      scroll(editor)
      expect(editor).toHaveDecorations color: '01', length: 2, text: 'orange'
      expect(editor).toHaveDecorations color: '02', length: 1, text: 'apple'
      scroll(editor)
      expect(editor).toHaveDecorations color: '01', length: 0
      expect(editor).toHaveDecorations color: '02', length: 3, text: 'apple'
