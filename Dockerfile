FROM node:20-alpine

WORKDIR /app

# Install only production dependencies for leaner image.
COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

ENV NODE_ENV=production
EXPOSE 80

CMD ["npm", "run", "start:force"]
