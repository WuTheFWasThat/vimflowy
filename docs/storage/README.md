# Vimflowy data storage

Vimflowy was designed to work with multiple storage backends.

## Local vs. Remote

First, the data can either be local on your computer, or hosted elsewhere.

By default, the app is entirely local meaning:
- Your data is never sent over the internet, so you can only use it in one browser on one device
- Vimflowy works offline

If you enable a remote storage backend, then:
- You can access your document from multiple devices
- You cannot edit offline

Keep in mind that even with remote storage backends, you won't be able to use vimflowy collaboratively - only one person can view/edit at a time.

## Options

### HTML5 localStorage (local)

This is the default option, storing data using modern browsers' HTML5 localStorage API.
- If you're going to have a very large document, use a browser with large localStorage limits, e.g. Firefox
- Be warned that if you don't set up remote storage, *clearing localStorage will result in you losing all your data!*

### Firebase (Google hosting)

With Firebase, you can let Google host your data for you remotely.
Firebase is free, but you have to pay once your document is huge, or if you want automated backups.

See [here](docs/storage/Firebase.md) for details on how to set this up.

### SQLite (self-hosting)

You can run a custom vimflowy backend server that stores the data.
You can choose to host it on your own computer, or on a remote server (if you want to access it from multiple places).

Currently, the vimflowy server stores the data in SQLite (which stores data in a file), but other methods could be added in the future.

See [here](docs/storage/SQLite.md) for details on how to set this up.

## Other backends

Please contact the dev team if you are interested in other storage backends.
It's relatively easy to add new ones!
