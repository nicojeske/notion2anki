FROM node:12-alpine AS BUILD_IMAGE

RUN apk add --no-cache  git curl bash && rm -rf /var/cache/apk/*
RUN rm -rf /var/lib/apt/lists/*
# install node-prune (https://github.com/tj/node-prune)
RUN curl -sfL https://install.goreleaser.com/github.com/tj/node-prune.sh | bash -s -- -b /usr/local/bin

WORKDIR /app


COPY package.json .
RUN npm install

COPY . .
RUN npm run build

# run node prune
RUN /usr/local/bin/node-prune

FROM node:12-alpine

RUN apk add --no-cache python3 py-pip && rm -rf /var/cache/apk/*
COPY ./src/genanki/requirements.txt .
RUN pip3 install -r ./requirements.txt

WORKDIR /app

COPY --from=BUILD_IMAGE /app .

ENV PORT 8080
EXPOSE 8080

CMD ["./node_modules/.bin/imba", "./src/server/server.imba"]
