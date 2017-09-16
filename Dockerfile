FROM node:6-stretch as build
LABEL maintainer="will.price94@gmail.com"
LABEL version="0.0.1"
RUN apt-get update -qq && \
    apt-get install -y python
WORKDIR /app/
COPY package.json package-lock.json /app/
RUN npm install
COPY . /app/
RUN npm run build
RUN npm test

FROM node:6-stretch
COPY --from=build /app /app
WORKDIR /app
VOLUME /app/db
EXPOSE 3000
ENV VIMFLOWY_PASSWORD=vimflowy123
ENTRYPOINT npm start -- \
    --prod \
    --host 0.0.0.0 \
    --port 3000 \
    --db sqlite \
    --dbfolder $HOME/db \
    --password $VIMFLOWY_PASSWORD
