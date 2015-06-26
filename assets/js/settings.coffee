class Settings
  default_settings:
    theme: 'default-theme'
  constructor: (mainDiv, data) ->
    @mainDiv = mainDiv
    @data = data
    do @populateDefaultSettings # TODO: Move into data.coffee in case we ever add an asynchronous datastore
  bind: () ->
    settings = this
    @mainDiv.find("#theme-selection").on 'input', (e) ->
      theme = @value
      settings.data.setSetting('theme', theme)
      settings.changeStyle(theme)
  loadRenderSettings: () ->
    theme = @data.getSetting 'theme'
    @changeStyle(theme)
    @mainDiv.find("#theme-selection").val theme
  populateDefaultSettings: () ->
    for setting in @default_settings when not (@data.getSetting setting)?
      @data.setSetting setting, @default_settings[setting]
  changeStyle: (theme) ->
    $('body').removeClass().addClass(theme)
