# ![Vimflowy](/static/images/vimflowy-32.png?raw=true) Vimflowy

[![Join Gitter chat](https://badges.gitter.im/WuTheFWasThat/vimflowy.svg)](https://gitter.im/WuTheFWasThat/vimflowy)
[![Build Status](https://travis-ci.org/WuTheFWasThat/vimflowy.svg?branch=master)](https://travis-ci.org/WuTheFWasThat/vimflowy)

This is a productivity tool which draws great inspiration from workflowy and vim.

[Try it out!](https://vimflowy.bitballoon.com)

(Video coming eventually...)

## FEATURES

- Workflowy features
  - tree-like outlining
  - collapsing and zooming into bullets
  - basic text formatting, strike through task completion
- Vim features
  - (configurable) vim keybindings
  - modal editing
  - undo history, location history, macros, etc.
- Extras
  - data import/export
  - loads data lazily (good for huge documents)
  - search (not like vim's)
  - cloning (bullets with multiple parents)
  - different visual themes
- Plugins system (see [plugins.md](docs/plugins.md))
  - marks (not like vim's)
  - easy-motion for moving between bullets quickly
  - time-tracking

## LIMITATIONS

- Currently, you can only edit from one tab at a time.
  There will likely never be collaboration features.
- Tested mostly in recent Chrome and Firefox.  You may need a relatively modern browser.

## DATA STORAGE

Vimflowy was designed to work with multiple storage backends.

### Local

By default, the app is entirely local meaning:
- Your data is never sent over the internet, so you can only use it in one browser on one device
- Vimflowy works offline

It uses HTML5's localStorage, so:
- If you're going to have a very large document, use a browser with large localStorage limits, e.g. Firefox
- Be warned: clearing localStorage will result in you losing all your data!

### Remote

If you enable a remote storage backend, then:
- You can access your document from multiple devices
- You cannot edit offline

Currently, the only storage backend implemented is Firebase.
See [here](docs/storage/Firebase.md) for details on how to set this up.

Please contact the dev team if you are interested in other storage backends.

## NOTES FOR DEVELOPERS

Contributions are very welcome!
See [dev_setup.md](docs/dev_setup.md) to see how to get started with a development setup.

#### LICENSE

MIT: https://wuthefwasthat.mit-license.org/

## FAQ (AKA questions I imagine people would ask me)

#### Why vim?

This is a productivity tool, and I find vim productive, once you get past the learning curve.
Of course, vim isn't for everyone.  But if you do a lot of editing of text, I recommend giving it a try.

#### Why workflowy?

Again, it's not for everyone, but I like Workflowy for the simplicity and lack of clutter.

#### I like this.  What else should I consider?

If you like both vim and workflowy, the best alternative I know of is spacemacs with the org layer (i.e. emacs org mode with vim keybindings).
Org mode is extremely powerful. I recommend trying it out.

There are pros and cons compared to vimflowy, which is more tailored for my particular workflow.
I'm curious how they compare for others, so if you try both, let me know what you think!

#### Why doesn't *mumble* work like vim?

My goal is to make Vimflowy feel like home to vim users.
That said, Vimflowy also intentionally differs in few ways, partially due to its Workflowy-inspired half.
Some known inconsistencies with vim are documented [here](docs/vim_inconsistencies.md).
Also, vim has a lot of stuff, to implement so there are some missing features.

If you find that something is incongruous with your vim use, whether a bug or missing feature, make an issue. Or better yet, a pull request!

