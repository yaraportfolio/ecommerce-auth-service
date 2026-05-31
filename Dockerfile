FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY src/ ./src/

FROM node:18-alpine
WORKDIR /app

# --- CORRECTION SÉCURITÉ ---
# On force la mise à jour de libcrypto3 et libssl3 vers la version patchée
# RUN apk update && \
#     apk add --no-cache "libcrypto3>=3.3.6-r0" "libssl3>=3.3.6-r0" && \
#     rm -rf /var/cache/apk/*

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
COPY --from=builder --chown=nodejs:nodejs /app /app
USER nodejs
EXPOSE 3001
ENV NODE_ENV=production PORT=3001
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/api/auth/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"
CMD ["node", "src/server.js"]
