FROM node:lts-alpine3.13 as BUILD_IMAGE

WORKDIR /app

COPY . .
RUN yarn
RUN yarn run webpack --mode=production
RUN yarn run build-server


RUN apk add --no-cache python3 py-pip && rm -rf /var/cache/apk/*
COPY ./src/genanki/requirements.txt .
RUN pip3 install -r ./requirements.txt

ENV PORT 8080
EXPOSE 8080

CMD ["./node_modules/.bin/imba", "./src/server/server.imba"]

# #docker run --rm -it --name n2a -p 8080:8080 n2a
##docker kill n2a & docker build -t n2a . & docker run --rm --name n2a -p 8080:8080 n2a