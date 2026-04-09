FROM node:20-alpine AS webapp-builder

WORKDIR /app/webapp

ARG VITE_SCAN_WEBHOOK_URL
ENV VITE_SCAN_WEBHOOK_URL=$VITE_SCAN_WEBHOOK_URL
# Coolify may pass NODE_ENV=production at build-time. Force dev deps in builder stage.
ENV NODE_ENV=development

COPY webapp/package*.json ./
RUN npm ci --include=dev --ignore-scripts
COPY webapp/ ./
RUN npm run build


FROM node:20-alpine

WORKDIR /app

# Install only production dependencies for leaner image.
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts

COPY . .
COPY --from=webapp-builder /app/webapp/dist ./webapp/dist

ENV NODE_ENV=production
EXPOSE 80

CMD ["npm", "run", "start:force"]
