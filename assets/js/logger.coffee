###
A straightforward class for configurable logging
Log-levels and streams (currently only one stream at a time)
###

LEVEL = {
  DEBUG: 0
  INFO: 1
  WARN: 2
  ERROR: 3
  FATAL: 4
}

STREAM = {
  STDOUT: 0
  STDERR: 1
  QUEUE: 2
}

class Logger
  constructor: (level=LEVEL.INFO, stream=STREAM.STDOUT) ->
    @setLevel level
    @setStream stream

    register_loglevel = (name, value) =>
      @[name.toLowerCase()] = () ->
        if @level <= value
          @log.apply @, arguments

    for name, value of LEVEL
      register_loglevel(name, value)
    return

  log: () ->
    if @stream == STREAM.STDOUT
      console.log.apply console, arguments
    else if @stream == STREAM.STDERR
      console.error.apply(console, arguments)
    else if @stream == STREAM.QUEUE
      @queue.push(arguments)

  setLevel: (level) ->
    @level = level

  off: () ->
    @level = Infinity

  setStream: (stream) ->
    @stream = stream
    if @stream == STREAM.QUEUE
      @queue = []

  # for queue

  flush: () ->
    if @stream == STREAM.QUEUE
      for args in @queue
        console.log.apply console, args
      do @empty

  empty: () ->
    @queue = []

exports.Logger = Logger
exports.LEVEL = LEVEL
exports.STREAM = STREAM

exports.logger = new Logger(LEVEL.DEBUG)
