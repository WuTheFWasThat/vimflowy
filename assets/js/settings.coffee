###
Represents user settings
Uses a datastore key which is agnostic to which document is being viewed
(i.e. /blah and /blah2 have the same settings)
###

default_settings:
  theme: 'default-theme'
  showKeyBindings: true
  hotkeys: {}

class Settings

  constructor: (datastore, options = {}) ->
    @datastore = datastore

    @mainDiv = options.mainDiv
    @keybindingsDiv = options.keybindingsDiv

    for setting of @default_settings when not (@getSetting setting)?
      @setSetting setting, @default_settings[setting]

  getSetting: (setting) ->
    @datastore.getSetting setting

  setSetting: (setting, value) ->
    @datastore.setSetting setting, value

module.exports = Settings
