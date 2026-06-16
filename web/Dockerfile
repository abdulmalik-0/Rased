# --- build the React app ---
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# --- serve via nginx; backend URL is injected at RUNTIME via /config.js ---
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
# nginx:alpine runs every *.sh in this dir on startup (before nginx itself).
COPY docker/40-rased-config.sh /docker-entrypoint.d/40-rased-config.sh
RUN chmod +x /docker-entrypoint.d/40-rased-config.sh
EXPOSE 80
