# DEPLOYMENT

Vimflowy supports deployment with docker, check out the
[`Dockerfile`](/Dockerfile) for technical details, or head over to [Docker
hub](https://hub.docker.com/r/vimflowy/vimflowy/) for ops details.

## Example deployment

Tested on an Ubuntu 16.04 server running docker `17.05.0-ce`.

First we create a volume called `vimflowy-db` to hold the
[SQLite](storage/SQLite.md) databases. Then we run vimflowy container mounting
in the `vimflowy-db` volume

```
$ docker volume create vimflowy-db
$ docker run -d \
             -e VIMFLOWY_PASSWORD=supersecretpassword \
             --name vimflowy \
             --mount source=vimflowy-db,target=/app/db \
             -p 3000:3000 \
             --restart unless-stopped \
             vimflowy/vimflowy
```

## Environment variables

You can override certain aspects of the container through environment variables (specified in `-e` options in the `docker run` command).

* `VIMFLOWY_PASSWORD`: The server password, specified by the user in *Settings > Data Storage > Vimflowy Server*
