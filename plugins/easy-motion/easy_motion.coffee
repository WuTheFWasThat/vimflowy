Plugins = require '../../assets/js/plugins'

Plugins.register {
  name: "Easy motion"
  author: "Jeff Wu"
  description: "Lets you easily jump between rows.  Based on https://github.com/easymotion/vim-easymotion"
}, ((api) ->
  EASY_MOTION_MAPPINGS = null

  CMD_EASY_MOTION = api.registerCommand {
    name: 'EASY_MOTION'
    default_hotkeys:
      normal_like: ['space']
  }

  api.registerMotion CMD_EASY_MOTION, {
    description: 'Jump to a visible row (based on EasyMotion)',
    multirow: true,
  }, () ->
    key = do @keyStream.dequeue
    if key == null
      do @keyStream.wait

      paths = (do @session.getVisiblePaths).filter \
        (path) => not (path.is @session.cursor.path)

      keys = [
        'Z', 'X', 'C', 'V',
        'Q', 'W', 'E', 'R', 'T',
        'A', 'S', 'D', 'F',
        'z', 'x', 'c', 'v',
        'q', 'w', 'e', 'r', 't',
        'a', 's', 'd', 'f',
        'g', 'h', 'j', 'k', 'l',
        'y', 'u', 'i', 'o', 'p',
        'b', 'n', 'm',
        'G', 'H', 'J', 'K', 'L',
        'Y', 'U', 'I', 'O', 'P',
        'B', 'N', 'M',
      ]

      if keys.length > paths.length
        start = (keys.length - paths.length) / 2
        keys = keys.slice(start, start + paths.length)
      else
        start = (paths.length - keys.length) / 2
        paths = paths.slice(start, start + paths.length)

      mappings = {
        key_to_path: {}
        path_to_key: {}
      }
      for [path, key] in _.zip(paths, keys)
        mappings.key_to_path[key] = path
        mappings.path_to_key[JSON.stringify do path.getAncestry] = key
      EASY_MOTION_MAPPINGS = mappings

      return null
    else
      return (cursor, options) ->
        if key of EASY_MOTION_MAPPINGS.key_to_path
          path = EASY_MOTION_MAPPINGS.key_to_path[key]
          cursor.set(path, 0)
        EASY_MOTION_MAPPINGS = null

  api.registerHook 'session', 'renderBullet', (bullet, info) ->
    ancestry_str = JSON.stringify do info.path.getAncestry
    if EASY_MOTION_MAPPINGS and ancestry_str of EASY_MOTION_MAPPINGS.path_to_key
      char = EASY_MOTION_MAPPINGS.path_to_key[ancestry_str]
      bullet = virtualDom.h 'span', {className: 'bullet theme-text-accent easy-motion'}, [char]
    return bullet
), ((api) ->
  do api.deregisterAll
)
