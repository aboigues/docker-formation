FROM node:24-alpine

WORKDIR /usr/src/app

# Les dépendances d'abord : tant que package.json ne change pas, ce layer est mis en cache.
COPY package.json package-lock.json* ./
RUN npm install --omit=dev && npm cache clean --force

COPY server.js ./

ENV NODE_ENV=production
EXPOSE 3000
USER node

CMD ["node", "server.js"]
