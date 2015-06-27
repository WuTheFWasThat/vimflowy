class Settings
  default_settings:
    theme: 'default-theme'
    export_filename: 'vimflowy.json'

  constructor: (mainDiv, data) ->
    @mainDiv = mainDiv
    @data = data
    do @populateDefaultSettings # TODO: Move into data.coffee in case we ever add an asynchronous datastore
    @data.registerSettings this

  getSetting: (setting) ->
    @data.getSetting setting

  populateDefaultSettings: () ->
    for setting of @default_settings when not (@data.getSetting setting)?
      @data.setSetting setting, @default_settings[setting]

  ###########
  # UI Glue #
  ###########

  bind: () ->
    settings = this
    @mainDiv.find("#theme-selection").on 'input', (e) ->
      theme = @value
      settings.data.setSetting 'theme', theme
      settings.changeStyle theme
    @mainDiv.find("#export-fileformat-selection").on 'input', (e) ->
      settings.data.setSetting 'export_filename', @value

  loadRenderSettings: () ->
    @changeStyle (@data.getSetting 'theme')
    # Populate setings menu itself as well
    @mainDiv.find("#theme-selection").val (@data.getSetting 'theme')
    @mainDiv.find("#export-fileformat-selection").val (@data.getSetting 'export_filename')

  ####################
  # Setting-specific #
  ####################

  changeStyle: (theme) ->
    $('body').removeClass().addClass(theme)
