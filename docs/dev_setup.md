## DEVELOPMENT SETUP

For development, you'll want to run vimflowy locally.
My aim is for setup to be painless, so let me know if anything goes awry.

### Installation

With recent versions of node (6.x) and npm:

    git clone https://github.com/WuTheFWasThat/vimflowy.git
    cd vimflowy
    npm install

### Run

Simply run:

    npm start

After a short wait, you should see the app at `http://localhost:3000/`
When source code changes, assets should be automatically (incrementally) recompiled.

To use a different port, you can do

    npm start -- --port 2002

For a full set of options, see

    npm start -- --help

Note that you may make new documents simply by visiting
`http://localhost:3000?doc=<documentname>#`

NOTE: You may notice that the development version is a bit slow.
If you're looking to run vimflowy for personal usage (not development), you'll want to compile the assets in production mode:

    npm run build
    npm run startprod

Notably, you can run a SQLite backend, for persistence to your server. 
[See here for more info](storage/SQLite.md).

### Tests

To run unit tests automatically (when files change) from the development server, add the `test` flag:

    npm start -- --test

To run a separate continuous process that monitors and runs tests when files change:

    npm run watchtest

To run unit tests manually once (and get a more detailed report):

    npm test

#### Typechecking

To manually run typescript checking:

    npm run typecheck

#### Linting

To manually lint the project:

    npm run lint

### Profiling

For profiling, you should use browser profiling when possible.
However, though the results will be less realistic, you can also profile unit tests.  Something like:

    mocha --prof --opts test/mocha.opts
    node-tick-processor *-v8.log > processed_log
    less processed_log

## Guidelines to contributing

Just send a pull request.  Remember to write tests when appropriate!

For any questions, don't hesitate to submit an issue or contact me at [githubusername]@gmail.com.  Let me know especially if you plan on adding new features!  I'm happy to chat about design, give pointers for where to start reading code, etc.

I've marked a number of github issues with the label `small_task`, which could be good places to start.
