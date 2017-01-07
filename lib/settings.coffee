inferType = (value) ->
  switch
    when Number.isInteger(value) then 'integer'
    when typeof(value) is 'boolean' then 'boolean'
    when typeof(value) is 'string' then 'string'
    when Array.isArray(value) then 'array'

class Settings
  constructor: (@scope, @config) ->
    # Automatically infer and inject `type` of each config parameter.
    # skip if value which aleady have `type` field.
    for key in Object.keys(@config)
      unless (value = @config[key]).type?
        value.type = inferType(value.default)

    # [CAUTION] injecting order propety to set order shown at setting-view MUST-COME-LAST.
    for name, i in Object.keys(@config)
      @config[name].order = i

  get: (param) ->
    atom.config.get "#{@scope}.#{param}"

  set: (param, value) ->
    atom.config.set "#{@scope}.#{param}", value

  toggle: (param) ->
    @set(param, not @get(param))

  observe: (param, fn) ->
    atom.config.observe "#{@scope}.#{param}", fn

module.exports = new Settings 'quick-highlight',
  decorate:
    default: 'underline'
    enum: ['underline', 'box', 'highlight']
    description: "Decoation style for highlight"
  highlightSelection:
    default: true
  highlightSelectionMinimumLength:
    default: 2
    description: "Minimum length of selection to be highlight"
  highlightSelectionExcludeScopes:
    default: ['vim-mode-plus.visual-mode.blockwise']
    items: {type: 'string'}
  highlightSelectionDelay:
    default: 100
    description: "Delay(ms) before start to highlight selection when selection changed"
  displayCountOnStatusBar:
    default: true
    description: "Show found count on StatusBar"
  countDisplayPosition:
    default: 'Left'
    enum: ['Left', 'Right']
  countDisplayPriority:
    default: 120
    description: "Lower priority get closer position to the edges of the window"
  countDisplayStyles:
    default: 'badge icon icon-location'
    description: "Style class for count span element. See `styleguide:show`."
