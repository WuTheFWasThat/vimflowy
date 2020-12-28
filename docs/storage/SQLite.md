# SQLite backend for vimflowy

## Info

While vimflowy is a server-less app, it's possible to also run a backend server to keep your data.
The vimflowy backend server communicates with the browser via websockets, while storing the data in SQLite.
While SQLite is the only option for now, more may be added in the future.

You can run the vimflowy server on your personal computer, for a local and offline vimflowy.
You can also host it on an external server, so you can access it from multiple devices.  In that case, you can protect access with a password.

## Setup

### Run the vimflowy server

All commands in this section are on your server/computer where you're hosting.

First, install vimflowy

    git clone https://github.com/WuTheFWasThat/vimflowy.git
    cd vimflowy
    npm install

Build assets

    npm run build

Then, run the server.

    npm run startprod -- --db sqlite --dbfolder ${somefolder} --password ${somepassword}

The `dbfolder` flag says where to store/load data.  If left empty, an in-memory database is used.

The `password` flag is optional.  Of course, it's wise to set one if you're using a widely accessible server, but pointless if you're hosting on your personal computer.

You can also change the port (from the default of 3000) with the `--port ${portnumber}` flag.

### Configure Vimflowy

Now open Vimflowy in your browser.
The server you ran will also host a version of the website (though you can also use https://wuthejeff.com/vimflowy).
On the page, click Settings in the lower right.
Select the `Vimflowy server` option under `Data Storage`.

Under the `Server` form field, you'll want to enter an address to connect to.  It should be `ws://localhost:3000`, if you ran locally, and something like `wss://yourwebsite.com:3000`, or `wss://54.0.0.1:3000` otherwise.
Under `Password`, enter a password if you configured one.
Under the `Document` form field, you can optionally enter the name of the document.

Then hit `Load Data Settings`.
This should refresh the page automatically.
If you see no errors, everything should be successful!

### Verify

Check the settings menu again and you should see that the `Vimflowy server` option is already selected.

You should also inspect the SQLite file in the `dbfolder` specified, and make sure it contains data.

## Backups

Data backups are done simply by backing up your SQLite backups (e.g. obtain db lock, then copy file).
You could also consider simply keeping the SQLite file in Dropbox (although Dropbox warns against this, it should work as long as it's not written to from other machines).
