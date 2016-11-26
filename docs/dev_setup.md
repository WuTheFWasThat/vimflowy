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

When source code changes, assets should be automatically recompiled and tests automatically re-ran.

Note that you may make new documents simply by visiting `http://localhost:3000?doc=<documentname>`

### Tests

Tests are run automatically with `npm start`.

To run unit tests manually and get a more detailed report, run:

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

For any questions, don't hesitate to submit an issue or contact me at [githubusername]@gmail.com.

I've marked a number of github issues with the label `small_task`, which could be good places to start.
