FROM node:22-alpine

WORKDIR /app

RUN corepack enable

COPY package.json yarn.lock ./
RUN YARN_NODE_LINKER=node-modules yarn install --immutable --mode=skip-build

COPY src ./src

EXPOSE 8083

CMD ["node", "src/server.js"]
