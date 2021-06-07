FROM node:10-stretch AS build
# Prevent npm from spamming
ENV NPM_CONFIG_LOGLEVEL=warn
RUN npm config set progress=false
WORKDIR /app/
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN REACT_APP_SERVER_CONFIG='{"socketserver": true}' npm run build
RUN npm install -g typescript
#build server
RUN tsc server/prod.ts --outDir dist  -m CommonJS --moduleResolution node --esModuleInterop --skipLibCheck  --target ES5 --lib ES5,ScriptHost,ESNext.AsyncIterable

FROM node:10-alpine
WORKDIR /app
RUN mkdir -p /app/build
COPY server.package.json ./package.json
COPY --from=build /app/build/ /app/build
#copy server js
COPY --from=build /app/dist /app
RUN npm i
VOLUME /app/db
EXPOSE 3000
ENV VIMFLOWY_PASSWORD=
ENTRYPOINT npm run start -- \
    --host 0.0.0.0 \
    --port 3000 \
    --staticDir /app/build \
    --db sqlite \
    --dbfolder /app/db \
    --password $VIMFLOWY_PASSWORD
