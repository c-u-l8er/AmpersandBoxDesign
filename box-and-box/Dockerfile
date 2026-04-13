FROM node:20-slim AS build

# Copy entire AmpersandBoxDesign context to preserve relative paths
# (bundle.js needs ../../protocol/ etc.)
COPY . /ampersand
WORKDIR /ampersand/box-and-box

RUN npm ci
RUN npm rebuild
RUN npm run build

FROM node:20-slim
RUN apt-get update -y && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /ampersand/box-and-box/dist ./dist
COPY --from=build /ampersand/box-and-box/bin ./bin
COPY --from=build /ampersand/box-and-box/bundled ./bundled
COPY --from=build /ampersand/box-and-box/node_modules ./node_modules
COPY --from=build /ampersand/box-and-box/package.json ./

RUN mkdir -p /data
ENV BOX_AND_BOX_DB_PATH=/data/specs.db

EXPOSE 8080
CMD ["node", "bin/box-and-box.js", "--transport", "http", "--port", "8080", "--db", "/data/specs.db"]
