((exports) ->
  LEVEL = {
    DEBUG: 0
    INFO: 1
    WARN: 2
    ERROR: 3
    FATAL: 4
  }

  class Logger
    constructor: (level=LEVEL.INFO) ->
      @level = level

      register_loglevel = (name, value) =>
        @[name.toLowerCase()] = () ->
          if @level <= value
            @log.apply @, arguments

      for name, value of LEVEL
        register_loglevel(name, value)
      return

    log: () ->
      console.log.apply console, arguments

    setLevel: (level) ->
      @level = level

    off: () ->
      @level = Infinity

  exports.Logger = Logger
  exports.LEVEL = LEVEL

  exports.logger = new Logger(LEVEL.DEBUG)
)(if typeof exports isnt 'undefined' then exports else window.Logger = {})
