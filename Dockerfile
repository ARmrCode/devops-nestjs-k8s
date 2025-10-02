FROM node:20-alpine AS build
WORKDIR /app

# Сначала зависимости
COPY package*.json ./
RUN npm ci \
    && npm install prom-client @types/prom-client --save --save-exact

# Копируем исходники и собираем
COPY . .
RUN npm run build

# Runtime stage
FROM node:20-alpine AS runtime
WORKDIR /app

RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
    && apk add --no-cache dumb-init

COPY package*.json ./
# Ставим runtime-зависимости + prom-client (без dev-зависимостей)
RUN npm ci --omit=dev \
    && npm install prom-client --save --save-exact

COPY --from=build /app/dist ./dist

USER appuser
EXPOSE 3000
ENV NODE_ENV=production

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "dist/main.js"]
