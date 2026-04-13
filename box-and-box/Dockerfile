FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm rebuild
RUN npm run build

FROM node:20-slim
RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/bin ./bin
COPY --from=build /app/bundled ./bundled
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./

RUN mkdir -p /data
ENV BOX_AND_BOX_DB_PATH=/data/specs.db

EXPOSE 8080
CMD ["node", "bin/box-and-box.js", "--transport", "http", "--port", "8080", "--db", "/data/specs.db"]
