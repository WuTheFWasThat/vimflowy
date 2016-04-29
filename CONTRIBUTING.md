# Guidelines to contributing

Just send a pull request.  Remember to write tests when appropriate!

For any questions, you may contact me at [githubusername]@gmail.com.

## DEV SETUP: ##

For development, you'll probably want to run a web version of vimflowy locally.

#### INSTALL: ####

Assuming you have node and npm

    git clone https://github.com/WuTheFWasThat/vimflowy.git
    cd vimflowy
    npm install

#### START: ####

Just run

    npm start

And you can visit the app at `http://localhost:8080/`

Assets will be automatically recompiled when the source changes, and tests are automatically re-ran.

Note that you may make new documents simply by visiting `http://localhost:8080/somedocumentname`

#### RUN TESTS: ####

Tests are run automatically.  To get a more detailed report, run

    npm test

And for a test coverage report, run

    npm run coverage

and visit `localhost:8080/coverage.html`
