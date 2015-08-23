(() ->
  class Settings
    default_settings:
      theme: 'default-theme'
      export_filename: 'vimflowy.json'
      showKeyBindings: true
      hotkeys: {}

    constructor: (datastore, options = {}) ->
      @datastore = datastore

      @mainDiv = options.mainDiv
      @keybindingsDiv = options.keybindingsDiv

      do @populateDefaultSettings
      if @mainDiv then do @bind

    getSetting: (setting) ->
      @datastore.getSetting setting

    setSetting: (setting, value) ->
      @datastore.setSetting setting, value

    populateDefaultSettings: () ->
      for setting of @default_settings when not (@getSetting setting)?
        @setSetting setting, @default_settings[setting]

    ###########
    # UI Glue #
    ###########

    bind: () ->
      me = @
      @mainDiv.find(".theme-selection").on 'input', (e) ->
        theme = @value
        me.setSetting 'theme', theme
        me.changeStyle theme
      @mainDiv.find(".export-fileformat-selection").on 'input', (e) ->
        me.setSetting 'export_filename', @value

    loadRenderSettings: () ->
      @changeStyle (@getSetting 'theme')
      # Populate setings menu itself as well
      @mainDiv.find(".theme-selection").val (@getSetting 'theme')
      @mainDiv.find(".export-fileformat-selection").val (@getSetting 'export_filename')

      if @getSetting 'showKeyBindings'
        @keybindingsDiv.addClass 'active'

    ####################
    # Setting-specific #
    ####################

    changeStyle: (theme) ->
      $('body').removeClass().addClass(theme)

  module?.exports = Settings
  window?.Settings = Settings
)()
