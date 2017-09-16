FROM node:6-stretch
LABEL maintainer="will.price94@gmail.com"
LABEL version="0.0.1"

RUN apt-get update -qq && \
    apt-get install -y python
RUN npm install -g yarn


ENV HOME=/app
RUN mkdir -p $HOME
RUN chown node:node $HOME
WORKDIR $HOME

COPY package.json yarn.lock $HOME/
RUN yarn

# TODO (when 17.09 lands): drop the line below the COPY and add --chown=node:node
COPY . $HOME
RUN npm run build
RUN npm run typecheck
RUN npm test

ENV DB_DIR=$HOME/db
ENV VIMFLOWY_PASSWORD=vimflowy123

VOLUME $DB_DIR

USER node
EXPOSE 3000
ENTRYPOINT npm start -- \
    --prod \
    --host 0.0.0.0 \
    --port 3000 \
    --db sqlite \
    --dbfolder $DB_DIR \
    --password $VIMFLOWY_PASSWORD
