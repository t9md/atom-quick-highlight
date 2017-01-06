{CompositeDisposable, Emitter} = require 'atom'

module.exports =
  class KeywordManager
    colorNumbers: ['01', '02', '03', '04', '05', '06', '07']

    onDidChangeKeyword: (fn) ->
      @emitter.on('did-change-keyword', fn)

    constructor: ->
      @emitter = new Emitter
      @colorsByKeyword = new Map

    has: (keyword) ->
      @colorsByKeyword.has(keyword)

    add: (keyword) ->
      @colorsByKeyword.set(keyword, @getNextColor())
      @emitter.emit('did-change-keyword')

    delete: (keyword) ->
      @colorsByKeyword.delete(keyword)
      @emitter.emit('did-change-keyword')

    toggle: (keyword) ->
      
      if @has(keyword)
        @delete(keyword)
      else
        @add(keyword)

    clear: ->
      @colorsByKeyword.clear()
      @colorIndex = null
      @emitter.emit('did-change-keyword')

    getNextColor: ->
      @colorIndex ?= -1
      @colorIndex = (@colorIndex + 1) % @colorNumbers.length
      @colorNumbers[@colorIndex]

    destroy: ->
      @clear()
