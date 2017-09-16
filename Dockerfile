FROM node:6-stretch
LABEL maintainer="will.price94@gmail.com"
LABEL version="0.0.1"

RUN apt-get update -qq && \
    apt-get install -y python


ENV HOME=/app
RUN mkdir -p $HOME
RUN chown node:node $HOME
WORKDIR $HOME

USER node
COPY package.json package-lock.json $HOME/
RUN npm install
COPY . $HOME # drop the line below and add --chown=node:node when 17.09 lands
RUN chown -r node:node $HOME/static
RUN npm run build
RUN npm run typecheck
RUN npm test

ENV DB_DIR=$HOME/db
ENV VIMFLOWY_PASSWORD=vimflowy123

VOLUME $DB_DIR

EXPOSE 3000
ENTRYPOINT npm start -- \
    --prod \
    --host 0.0.0.0 \
    --port 3000 \
    --db sqlite \
    --dbfolder $DB_DIR \
    --password $VIMFLOWY_PASSWORD
