class Settings
  default_settings:
    theme: 'default-theme'
  constructor: (mainDiv, data) ->
    @mainDiv = mainDiv
    @data = data
  bind: () ->
    settings = this
    @mainDiv.find("#theme-selection").on 'input', (e) ->
      theme = @value
      settings.data.setSetting('theme', theme)
      settings.changeStyle(theme)
  loadRenderSettings: () ->
    theme = @getSetting 'theme'
    @changeStyle(theme)
    @mainDiv.find("#theme-selection").val theme
  getSetting: (setting) -> # TODO: make data.coffee populate default settings directly during setup instead
    @data.getSetting(setting) ? @default_settings[setting]
  changeStyle: (theme) ->
    $('body').removeClass().addClass(theme)
