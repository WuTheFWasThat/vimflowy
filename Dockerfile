FROM node:6-stretch
LABEL maintainer="will.price94@gmail.com"
LABEL version="0.0.1"
RUN apt-get update -qq && \
    apt-get install -y python
# Prevent npm from spamming
RUN npm config set loglevel=warn && \
    npm config set progress=false
WORKDIR /app/
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

VOLUME /app/db
EXPOSE 3000
ENV VIMFLOWY_PASSWORD=vimflowy123
ENTRYPOINT npm start -- \
    --prod \
    --host 0.0.0.0 \
    --port 3000 \
    --db sqlite \
    --dbfolder /app/db \
    --password $VIMFLOWY_PASSWORD
