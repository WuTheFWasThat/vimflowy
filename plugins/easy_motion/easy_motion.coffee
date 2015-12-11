(() ->
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

        rows = (do @view.getVisibleRows).filter (row) =>
                 return not (row.is @view.cursor.row)
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

        if keys.length > rows.length
          start = (keys.length - rows.length) / 2
          keys = keys.slice(start, start + rows.length)
        else
          start = (rows.length - keys.length) / 2
          rows = rows.slice(start, start + rows.length)

        mappings = {
          key_to_row: {}
          row_to_key: {}
        }
        for [row, key] in _.zip(rows, keys)
          mappings.key_to_row[key] = row
          mappings.row_to_key[JSON.stringify do row.getAncestry] = key
        EASY_MOTION_MAPPINGS = mappings

        return null
      else
        return (cursor, options) ->
          if key of EASY_MOTION_MAPPINGS.key_to_row
            row = EASY_MOTION_MAPPINGS.key_to_row[key]
            cursor.set row, 0
          EASY_MOTION_MAPPINGS = null

    api.view.addRenderHook 'bullet', (bullet, info) ->
      ancestry_str = JSON.stringify do info.row.getAncestry
      if EASY_MOTION_MAPPINGS and ancestry_str of EASY_MOTION_MAPPINGS.row_to_key
        char = EASY_MOTION_MAPPINGS.row_to_key[ancestry_str]
        bullet = virtualDom.h 'span', {className: 'bullet theme-text-accent easy-motion'}, [char]
      return bullet

  )
)()
