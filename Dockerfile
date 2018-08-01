FROM node:8-stretch AS build
LABEL maintainer="will.price94@gmail.com"
LABEL version="0.0.1"
# Prevent npm from spamming
ENV NPM_CONFIG_LOGLEVEL=warn
RUN npm config set progress=false
WORKDIR /app/
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN mkdir -p /build/{client, server}
RUN npm run build -- --outdir /build/client --socketserver
RUN npm run buildserver -- --outdir /build/server

FROM node:8-alpine
WORKDIR /app
COPY --from=build /app/package.json /app/package-lock.json ./
RUN npm install --production
COPY --from=build /build/server/* ./
RUN mkdir -p /app/static
COPY --from=build /app/static/* /app/static/
COPY --from=build /build/client /app/static/build
VOLUME /app/db
EXPOSE 3000
ENV VIMFLOWY_PASSWORD=
ENTRYPOINT node /app/server.js \
    --host 0.0.0.0 \
    --port 3000 \
    --staticDir /app/static \
    --db sqlite \
    --dbfolder /app/db \
    --password $VIMFLOWY_PASSWORD
