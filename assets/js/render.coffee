# virtualDom = require 'virtual-dom'

constants = require './constants.coffee'
utils = require './utils.coffee'
Logger = require './logger.coffee'
Plugins = require './plugins.coffee'
Modes = require './modes.coffee'
MODES = Modes.modes
NORMAL_MODE_TYPE = Modes.NORMAL_MODE_TYPE
INSERT_MODE_TYPE = Modes.INSERT_MODE_TYPE
MODE_TYPES = Modes.types

# TODO: move mode-specific logic into mode render functions

containerDivID = (id) ->
  return 'node-' + id

rowDivID = (id) ->
  return 'node-' + id + '-row'

childrenDivID = (id) ->
  return 'node-' + id + '-children'

getCursorClass = (cursorBetween) ->
  if cursorBetween
    return 'theme-cursor-insert'
  else
    return 'theme-cursor'

renderLine = (lineData, options = {}) ->
  options.cursors ?= {}
  options.highlights ?= {}

  results = []

  # ideally this takes up space but is unselectable (uncopyable)
  cursorChar = ' '

  line = []

  # add cursor if at end
  if lineData.length of options.cursors
    lineData.push {char: cursorChar}

  if lineData.length == 0
    return results

  for obj, i in lineData
    info = {
      column: i
    }
    renderOptions = {}

    for property in constants.text_properties
      if obj[property]
        renderOptions[property] = true

    x = obj.char

    if obj.char == '\n'
      # tricky logic for rendering new lines within a bullet
      # (copies correctly, works when cursor is on the newline itself)
      x = ''
      info.break = true
      if i of options.cursors
        x = cursorChar + x

    if i of options.cursors
      renderOptions.cursor = true
    else if i of options.highlights
      renderOptions.highlight = true

    info.char = x
    info.renderOptions = renderOptions

    line.push info

  # collect set of words, { word: word, start: start, end: end }
  word_chars = []
  word_start = 0


  for obj, i in lineData.concat [{char: ' '}] # to make end condition easier
    # TODO  or (utils.isPunctuation obj.char)
    # problem is URLs have dots in them...
    if (utils.isWhitespace obj.char)
      if i != word_start
        word_info = {
          word: word_chars.join('')
          start: word_start
          end: i - 1
        }
        if options.wordHook?
          line = options.wordHook line, word_info
        if utils.isLink word_info.word
          for j in [word_info.start..word_info.end]
            line[j].renderOptions.type = 'a'
            line[j].renderOptions.href = word_info.word
      word_start = i + 1
      word_chars = []
    else
      word_chars.push(obj.char)

  if options.lineHook?
    line = options.lineHook line

  renderSpec = []
  # Normally, we collect things of the same type and render them in one div
  # If there are column-specific handlers, however, we must break up the div to handle
  # separate click events
  if options.charclick
    for x in line
      x.renderOptions.text = x.char
      if not x.renderOptions.href
        x.renderOptions.onclick = options.charclick.bind @, x.column
      renderSpec.push x.renderOptions
      if x.break
        renderSpec.push {type: 'div'}
  else
    acc = []
    renderOptions = {}

    flush = () ->
      if acc.length
        renderOptions.text = acc.join('')
        renderSpec.push renderOptions
        acc = []
      renderOptions = {}

    # collect line into groups to render
    for x in line
      if JSON.stringify(x.renderOptions) == JSON.stringify(renderOptions)
        acc.push(x.char)
      else
        do flush
        acc.push(x.char)
        renderOptions = x.renderOptions

      if x.break
        do flush
        renderSpec.push {type: 'div'}
    do flush

  for spec in renderSpec
    classes = spec.classes or []
    type = spec.type or 'span'
    if type == 'a'
      classes.push 'theme-text-link'

    # make sure .bold, .italic, .strikethrough, .underline correspond to the text properties
    for property in constants.text_properties
      if spec[property]
        classes.push property

    if spec.cursor
      classes.push getCursorClass options.cursorBetween
    if spec.highlight
      classes.push 'theme-bg-highlight'

    divoptions = {}
    if classes.length
      divoptions.className = (classes.join ' ')
    if spec.href
      divoptions.href = spec.href
    if spec.onclick
      divoptions.onclick = spec.onclick
    if options.linemouseover
      divoptions.onmouseover = options.linemouseover

    results.push virtualDom.h type, divoptions, spec.text

  return results


renderSession = (session, options = {}) ->
  if session.menu
    renderMenu session.menu
    return

  if not session.vnode?
    # TODO: stop attaching things to the session
    session.vtree = virtualRenderSession session
    session.vnode = virtualDom.create session.vtree
    do session.mainDiv.empty
    session.mainDiv.append session.vnode
    return

  options.cursorBetween = (Modes.getMode session.mode).metadata.hotkey_type == Modes.INSERT_MODE_TYPE

  t = Date.now()
  vtree = virtualRenderSession session, options
  patches = virtualDom.diff session.vtree, vtree
  session.vnode = virtualDom.patch session.vnode, patches
  session.vtree = vtree
  Logger.logger.debug 'Rendering: ', !!options.handle_clicks, (Date.now()-t)

  cursorDiv = $(".#{getCursorClass options.cursorBetween}", session.mainDiv)[0]
  if cursorDiv
    session.scrollIntoView cursorDiv

  clearTimeout session.cursorBlinkTimeout
  session.mainDiv.removeClass("animate-blink-cursor")
  session.cursorBlinkTimeout = setTimeout (() ->
    session.mainDiv.addClass("animate-blink-cursor")
  ), 500

  return

virtualRenderSession = (session, options = {}) ->
  crumbs = []
  path = session.viewRoot
  until path.is session.document.root
    crumbs.push path
    path = path.parent

  makeCrumb = (path, isLast) ->
    m_options = {}
    if session.mode == MODES.NORMAL and not isLast
      m_options.className = 'theme-text-link'
      m_options.onclick = () ->
        session.zoomInto path
        do session.save
        renderSession session
    if isLast
      text = virtualRenderLine session, path, options
    else if path.is session.document.root
      text = virtualDom.h 'icon', {className: 'fa fa-home'}
    else
      text = (session.document.getText path.row).join('')
    return virtualDom.h 'span', { className: 'crumb' }, [
             virtualDom.h 'span', m_options, [ text ]
           ]

  crumbNodes = []
  crumbNodes.push(makeCrumb session.document.root)
  for i in [crumbs.length-1..0] by -1
    path = crumbs[i]
    crumbNodes.push(makeCrumb path, i==0)

  breadcrumbsNode = virtualDom.h 'div', {
    id: 'breadcrumbs'
  }, crumbNodes

  options.ignoreCollapse = true # since we're the root, even if we're collapsed, we should render

  options.highlight_blocks = {}
  if session.lineSelect
    # mirrors logic of finishes_visual_line in keyHandler.coffee
    [parent, index1, index2] = do session.getVisualLineSelections
    for child in session.document.getChildRange parent, index1, index2
      options.highlight_blocks[child.row] = true

  if session.document.hasChildren session.viewRoot.row
    contentsChildren = virtualRenderTree session, session.viewRoot, options
    contentsNode = virtualDom.h 'div', {}, contentsChildren
  else
    message = 'Nothing here yet.'
    if session.mode == MODES.NORMAL
      message += ' Press o to start adding content!'
    contentsNode = virtualDom.h 'div', {
      class: 'center',
      style: {
        'padding': '20px', 'font-size': '20px', 'opacity': '0.5'
      }
    }, message

  return virtualDom.h 'div', {}, [breadcrumbsNode, contentsNode]

virtualRenderTree = (session, parent, options = {}) ->
  if (not options.ignoreCollapse) and (session.document.collapsed parent.row)
    return

  childrenNodes = []

  for path in session.document.getChildren parent
    pathElements = []

    if session.document.isClone path.row
      cloneIcon = virtualDom.h 'i', { className: 'fa fa-clone bullet clone-icon', title: 'Cloned' }
      pathElements.push cloneIcon

    ancestry_str = JSON.stringify do path.getAncestry

    icon = 'fa-circle'
    if session.document.hasChildren path.row
      icon = if session.document.collapsed path.row then 'fa-plus-circle' else 'fa-minus-circle'

    bulletOpts = {
      className: 'fa ' + icon + ' bullet'
      attributes: {'data-id': path.row, 'data-ancestry': ancestry_str}
    }
    if session.document.hasChildren path.row
      bulletOpts.style = {cursor: 'pointer'}
      bulletOpts.onclick = ((path) ->
        session.toggleBlockCollapsed path.row
        do session.save
        renderSession session
      ).bind(@, path)

    bullet = virtualDom.h 'i', bulletOpts
    bullet = session.applyHook 'renderBullet', bullet, { path: path }

    pathElements.push bullet

    elLine = virtualDom.h 'div', {
      id: rowDivID path.row
      className: 'node-text'
      # if clicking outside of text, but on the row, move cursor to the end of the row
      onclick:  ((path) ->
        col = if options.cursorBetween then -1 else -2
        session.cursor.set path, col
        renderSession session
      ).bind(@, path)
    }, (virtualRenderLine session, path, options)
    pathElements.push elLine

    options.ignoreCollapse = false
    children = virtualDom.h 'div', {
      id: childrenDivID path.row
      className: 'node-children'
    }, (virtualRenderTree session, path, options)
    pathElements.push children

    className = 'node'
    if path.row of options.highlight_blocks
      className += ' theme-bg-highlight'

    pathElements = session.applyHook 'renderPathElements', pathElements, { path: path }

    childNode = virtualDom.h 'div', {
      id: containerDivID path.row
      className: className
    }, pathElements

    childrenNodes.push childNode
  return childrenNodes

virtualRenderLine = (session, path, options = {}) ->
  lineData = session.document.getLine path.row
  cursors = {}
  highlights = {}

  if path.is session.cursor.path
    cursors[session.cursor.col] = true

    if session.anchor and not session.lineSelect
      if session.anchor.path? and path.is session.anchor.path
        for i in [session.cursor.col..session.anchor.col]
          highlights[i] = true
      else
        Logger.logger.warn "Multiline not yet implemented"

    cursors = session.applyHook 'renderCursorsDict', cursors, { path: path }

  results = []

  lineoptions = {
    cursors: cursors
    highlights: highlights
    cursorBetween: options.cursorBetween
  }

  if options.handle_clicks
    if session.mode == MODES.NORMAL or session.mode == MODES.INSERT
      lineoptions.charclick = (column, e) ->
        session.cursor.set path, column
        # assume they might click again
        renderSession session, {handle_clicks: true}
        # prevent overall path click
        do e.stopPropagation
        return false
  else if not options.no_clicks
    lineoptions.linemouseover = () ->
      renderSession session, {handle_clicks: true}

  lineoptions.wordHook = session.applyHook.bind session, 'renderLineWordHook'
  lineoptions.lineHook = session.applyHook.bind session, 'renderLineTextOptions'

  lineContents = renderLine lineData, lineoptions
  lineContents = session.applyHook 'renderLineContents', lineContents, { path: path }
  [].push.apply results, lineContents

  infoChildren = session.applyHook 'renderInfoElements', [], { path: path }
  info = virtualDom.h 'span', {
    className: 'node-info'
  }, infoChildren
  results.push info

  results = session.applyHook 'renderLineElements', results, { path: path }

  return results


renderMenu = (menu) ->
  if not menu.div
    return

  do menu.div.empty

  searchBox = $('<div>').addClass('searchBox theme-trim').appendTo menu.div
  searchBox.append $('<i>').addClass('fa fa-search').css(
    'margin-right': '10px'
  )

  searchRow = virtualDom.create virtualDom.h 'span', {}, (virtualRenderLine menu.session, menu.session.cursor.path, {cursorBetween: true, no_clicks: true})
  searchBox.append searchRow

  if menu.results.length == 0
    message = ''
    if do menu.session.curLineLength == 0
      message = 'Type something to search!'
    else
      message = 'No results!  Try typing something else'
    menu.div.append(
      $('<div>').html(message).css(
        'font-size': '20px'
        'opacity': '0.5'
      ).addClass('center')
    )
  else
    for result, i in menu.results

      resultDiv = $('<div>').css(
        'margin-bottom': '10px'
      ).appendTo menu.div

      icon = 'fa-circle'
      if i == menu.selection
        resultDiv.addClass 'theme-bg-selection'
        icon = 'fa-arrow-circle-right'
      resultDiv.append $('<i>').addClass('fa ' + icon + ' bullet').css(
        'margin-right': '20px'
      )

      renderOptions = result.renderOptions || {}
      contents = renderLine result.contents, renderOptions
      if result.renderHook?
        contents = result.renderHook contents
      resultLineDiv = virtualDom.create virtualDom.h 'span', {}, contents
      resultDiv.append resultLineDiv

renderPlugins = (pluginManager) ->
  unless pluginManager.div?
    return
  vtree = virtualRenderPlugins pluginManager
  if not pluginManager.vnode?
    pluginManager.vtree = vtree
    pluginManager.vnode = virtualDom.create pluginManager.vtree
    do pluginManager.div.empty
    pluginManager.div.append pluginManager.vnode
    return

  patches = virtualDom.diff pluginManager.vtree, vtree
  pluginManager.vtree = vtree
  pluginManager.vnode = virtualDom.patch pluginManager.vnode, patches

virtualRenderPlugins = (pluginManager) ->
  header = virtualDom.h 'tr', {}, [
    virtualDom.h 'th', { className: 'plugin-name' }, "Plugin"
    virtualDom.h 'th', { className: 'plugin-description' }, "Description"
    virtualDom.h 'th', { className: 'plugin-version' }, "Version"
    virtualDom.h 'th', { className: 'plugin-author' }, "Author"
    virtualDom.h 'th', { className: 'plugin-status' }, "Status"
    virtualDom.h 'th', { className: 'plugin-actions' }, "Actions"
  ]
  pluginElements = (virtualRenderPlugin pluginManager, name for name in do Plugins.names)
  virtualDom.h 'table', {}, ([header].concat pluginElements)

virtualRenderPlugin = (pluginManager, name) ->
  status = pluginManager.getStatus name
  actions = []
  if status == Plugins.STATUSES.ENABLED
    # "Disable" action
    button = virtualDom.h 'div', {
      className: 'btn theme-trim'
      onclick: () -> pluginManager.disable name
    }, "Disable"
    actions.push button
  else if status == Plugins.STATUSES.DISABLED
    # "Enable" action
    button = virtualDom.h 'div', {
      className: 'btn theme-trim'
      onclick: () -> pluginManager.enable name
    }, "Enable"
    actions.push button

  color = "inherit"
  if status == Plugins.STATUSES.ENABLING or status == Plugins.STATUSES.DISABLING
    color = "yellow"
  if status == Plugins.STATUSES.UNREGISTERED or status == Plugins.STATUSES.DISABLED
    color = "red"
  else if status == Plugins.STATUSES.ENABLED
    color = "green"

  plugin = (Plugins.get name) || {}
  virtualDom.h 'tr', {
    className: "plugin theme-bg-secondary"
  }, [
    virtualDom.h 'td', { className: 'center theme-trim plugin-name' }, name
    virtualDom.h 'td', { className: 'theme-trim plugin-description', style: {'font-size': '12px'} }, (plugin.description || '')
    virtualDom.h 'td', { className: 'center theme-trim plugin-version' }, ((plugin.version || '') + '')
    virtualDom.h 'td', { className: 'center theme-trim plugin-author', style: {'font-size': '12px'} }, (plugin.author || '')
    virtualDom.h 'td', { className: 'center theme-trim plugin-status', style: {'box-shadow': 'inset 0px 0px 0px 2px ' + color } }, status
    virtualDom.h 'td', { className: 'center theme-trim plugin-actions' }, actions
  ]

######
# hotkeys
######
renderHotkeysTable = (key_bindings) ->
  $('#hotkey-edit-normal').empty().append(
    $('<div>').addClass('tooltip').text(NORMAL_MODE_TYPE).attr('title', MODE_TYPES[NORMAL_MODE_TYPE].description)
  ).append(
    buildTable key_bindings, key_bindings.hotkeys[NORMAL_MODE_TYPE], (_.extend.apply @, (_.cloneDeep (key_bindings.definitions.actions_for_mode mode) for mode in MODE_TYPES[NORMAL_MODE_TYPE].modes))
  )

  $('#hotkey-edit-insert').empty().append(
    $('<div>').addClass('tooltip').text(INSERT_MODE_TYPE).attr('title', MODE_TYPES[INSERT_MODE_TYPE].description)
  ).append(
    buildTable key_bindings, key_bindings.hotkeys[INSERT_MODE_TYPE], (_.extend.apply @, (_.cloneDeep (key_bindings.definitions.actions_for_mode mode) for mode in MODE_TYPES[INSERT_MODE_TYPE].modes))
  )

# build table to visualize hotkeys
buildTable = (key_bindings, keyMap, actions, helpMenu) ->
  buildTableContents = (bindings, onto, recursed=false) ->
    for k,v of bindings
      if k == 'MOTION'
        if recursed
          keys = ['<MOTION>']
        else
          continue
      else
        keys = keyMap[k]
        if not keys
          continue

      if keys.length == 0 and helpMenu
        continue

      row = $('<tr>')

      # row.append $('<td>').text keys[0]
      row.append $('<td>').text keys.join(' OR ')

      display_cell = $('<td>').css('width', '100%').html v.description
      if typeof v.definition == 'object'
        buildTableContents v.definition, display_cell, true
      row.append display_cell

      onto.append row

  tables = $('<div>')

  for [label, definitions] in [['Actions', actions], ['Motions', key_bindings.definitions.motions]]
    tables.append($('<h5>').text(label).css('margin', '5px 10px'))
    table = $('<table>').addClass('keybindings-table theme-bg-secondary')
    buildTableContents definitions, table
    tables.append(table)

  return tables

renderModeTable = (key_bindings, mode, onto) ->
  table = buildTable key_bindings, key_bindings.keyMaps[mode], (key_bindings.definitions.actions_for_mode mode), true
  onto.empty().append(table)

exports.virtualRenderLine = virtualRenderLine

exports.renderLine = renderLine
exports.renderSession = renderSession
exports.renderMenu = renderMenu
exports.renderPlugins = renderPlugins
exports.renderHotkeysTable = renderHotkeysTable
exports.renderModeTable = renderModeTable
