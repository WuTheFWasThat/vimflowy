FROM node:10-stretch AS build
LABEL maintainer="will.price94@gmail.com"
LABEL version="0.0.1"
# Prevent npm from spamming
ENV NPM_CONFIG_LOGLEVEL=warn
RUN npm config set progress=false
WORKDIR /app/
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN REACT_APP_SERVER_CONFIG='{"socketserver": true}' npm run build

FROM node:10-alpine
WORKDIR /app
COPY --from=build /app/package.json /app/package-lock.json ./
RUN npm install --production
RUN mkdir -p /app/build
COPY --from=build /app/build/ /app/build
VOLUME /app/db
EXPOSE 3000
ENV VIMFLOWY_PASSWORD=
ENTRYPOINT npm run startprod -- \
    --host 0.0.0.0 \
    --port 3000 \
    --staticDir /app/build \
    --db sqlite \
    --dbfolder /app/db \
    --password $VIMFLOWY_PASSWORD
