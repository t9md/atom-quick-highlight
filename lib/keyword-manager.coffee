{Emitter} = require 'atom'

module.exports =
  class KeywordManager
    colorNumbers: ['01', '02', '03', '04', '05', '06', '07']
    visibleEditors: null
    activeItem: null
    latestKeyword: null

    onDidAddKeyword: (fn) -> @emitter.on('did-add-keyword', fn)
    onDidDeleteKeyword: (fn) -> @emitter.on('did-delete-keyword', fn)
    onDidClearKeyword: (fn) -> @emitter.on('did-clear-keyword', fn)

    constructor: ->
      @emitter = new Emitter
      @colorsByKeyword = new Map

    has: (keyword) ->
      @colorsByKeyword.has(keyword)

    add: (keyword) ->
      color = @getNextColor()
      @colorsByKeyword.set(keyword, color)
      @latestKeyword = keyword
      @emitter.emit('did-add-keyword', {keyword, color})

    delete: (keyword) ->
      @colorsByKeyword.delete(keyword)
      @emitter.emit('did-delete-keyword', {keyword})

    toggle: (keyword) ->
      if @has(keyword)
        @delete(keyword)
      else
        @add(keyword)

    clear: ->
      @colorsByKeyword.clear()
      @colorIndex = null
      @emitter.emit('did-clear-keyword')

    getNextColor: ->
      @colorIndex ?= -1
      @colorIndex = (@colorIndex + 1) % @colorNumbers.length
      @colorNumbers[@colorIndex]

    destroy: ->
      @clear()
