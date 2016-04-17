###
Represents user settings
Uses a data store key which is agnostic to which document is being viewed
(i.e. /blah and /blah2 have the same settings)
###

class Settings
  default_settings:
    theme: 'default-theme'
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

  loadRenderSettings: () ->
    @changeStyle (@getSetting 'theme')
    # Populate setings menu itself as well
    @mainDiv.find(".theme-selection").val (@getSetting 'theme')

    if @getSetting 'showKeyBindings'
      @keybindingsDiv.addClass 'active'

  ####################
  # Setting-specific #
  ####################

  changeStyle: (theme) ->
    $('body').attr('id', theme)

module.exports = Settings
