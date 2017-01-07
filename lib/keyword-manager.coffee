{Emitter} = require 'atom'

module.exports =
  class KeywordManager
    colorNumbers: ['01', '02', '03', '04', '05', '06', '07']
    visibleEditors: null
    activeItem: null
    latestKeyword: null

    onDidChangeKeyword: (fn) -> @emitter.on('did-change-keyword', fn)
    emitDidChangeKeyword: -> @emitter.emit('did-change-keyword')

    constructor: ->
      @emitter = new Emitter
      @reset()

    reset: ->
      @keywordToColor = Object.create(null)
      @colorIndex = -1

    toggle: (keyword) ->
      if keyword of @keywordToColor
        delete @keywordToColor[keyword]
      else
        @keywordToColor[keyword] = @getNextColor()
        @latestKeyword = keyword
      @emitDidChangeKeyword()

    clear: ->
      @reset()
      @emitDidChangeKeyword()

    getNextColor: ->
      @colorIndex = (@colorIndex + 1) % @colorNumbers.length
      @colorNumbers[@colorIndex]

    destroy: ->
