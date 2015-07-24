((exports) ->

  exports.default_data = { line: '', children: [
    'Welcome to vimflowy!'
    '(I hope you know to use j and k to move up and down!)'
    { line: 'Features', children: [
      { line: 'Nested bullets', children: [
        { line: 'Use enter to zoom in to a bullet', children: [
          'And shift+enter to go all the way back out'
          'Use ] and [ to zoom in and out just one level'
        ] }
        { line: 'Collapsed bullets.  z to toggle collapsedness', collapsed: true, children: [
          'You found me! :)'
        ] }
        'Use < and > to indent and unindent blocks'
        'Use tab and shift+tab to indent and unindent just a single line'
      ] }
      { line: 'All the normal vim goodness', collapsed: true, children: [
        { line: 'Most of vim\'s movement commands', collapsed: true, children: [
          'h, j, k, and l'
          '$ and 0'
          'b, e, w, B, E, W'
          'f, t, F, T'
          'Can you figure out what alt+j and alt+k do?'
        ] }
        { line: 'Many of vim\'s operators', collapsed: true, children: [
          'd to delete, c to change'
          'x to delete a character, s to change it'
          'r to replace'
          'y to yank, p and P to paste'
          'J to join lines'
          {line: 'g to go places', children: [
            'g to go to the beginning of the visible document (just G to go to the end)'
            'p to go to the parent of the current line'
            'm to go to a @mark'
          ] }
        ] }
        '. to repeat the last command'
        'Macros! q and @, just like in vim'
        { line: 'Modal editing', collapsed: true, children: [
          { line: 'Insert mode', collapsed: true, children: [
            '... so that you can edit things!'
            'All the different vim ways to enter it: a, A, i, I, o, O'
            'esc or ctrl+c to exit'
          ] }
          { line: 'Visual mode', collapsed: true, children: [
            'Press v to enter visual mode'
            'It only works on one line, for now'
            'It lets you yank (y), delete (d or x) and change (c)'
          ] }
          { line: 'Visual line mode', collapsed: true, children: [
            'Press V to enter visual line mode'
            'It only works on sibling lines, for now'
            'It lets you yank (y), delete (d or x), change (c), and indent (< or >)'
          ] }
        ] }
        { line: 'Full history within a session', collapsed: true, children: [
          'Use u to undo and ctrl+r to redo'
          'And use . to repeat the last command'
          'You can define and use macros, just like in vim'
          'ctrl+o and ctrl+i will cycle through your zoom/jump history'
        ] }
      ] }
      { line: 'Search', collapsed: true, children: [
        'Press / to start searching, and then just type what you want to find'
        'ctrl+j and ctrl+k to page through the results'
        'enter to select what you want, and esc to cancel'
      ] }
      { line: 'Marks', mark: 'mark', collapsed: true, children: [
        { line: 'I am marked!', mark: 'im_a_mark', children: [] }
        'Press m to start marking a line, and enter to finish'
        'Use ` or \' to jump to marks'
        { line: 'Tag marks by typing @[markname], like this:  @im_a_mark', children: [
          'Click the tag to jump to the marked location.'
          'Alternatively, when your cursor is over the tag, type gm to jump to the mark'
        ] }
      ] }
      { line: 'Customizable', collapsed: true, children: [
        'Different color themes (see Settings)'
        # 'Customizable hotkeys'
      ] }
      # { line: 'Import and export data', collapsed: true, children: [
      #   ''
      # ] }
    ] }
    { line: 'Tips', collapsed: true, children: [
      'Collapse things often to avoid clutter.  Zoom into collapsed bullets'
      'Use ctrl+[hjkl] to move blocks of content around easily'
      'Use ? to hide the keybindings menu, once you become an expert'
      'Make many documents.  Just visit /documentname'
    ] }
    'Press i to enter insert mode and start adding your own content!'
    'For more info, visit https://github.com/WuTheFWasThat/vimflowy'
    # Please report bugs!
  ] }

)(if typeof exports isnt 'undefined' then exports else window.constants = {})
