FROM node:22-alpine
WORKDIR /app
COPY server.js index.html ./
EXPOSE 3001
CMD ["node", "server.js"]
