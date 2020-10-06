FROM node:12-alpine AS BUILD_IMAGE

RUN apk add --no-cache python3 py-pip git  && rm -rf /var/cache/apk/*
RUN rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ./src/genanki/requirements.txt .
RUN pip3 install -r ./requirements.txt

COPY package.json .
RUN npm install

COPY . .
RUN npm run build

FROM node:12-alpine

WORKDIR /app

COPY --from=BUILD_IMAGE /app/dist ./dist

ENV PORT 8080
EXPOSE 8080

CMD ["/app/node_modules/.bin/imba", "src/server/server.imba"]
