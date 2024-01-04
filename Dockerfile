FROM node:18-slim
COPY . .
RUN npm install
CMD [ "node", "index.js" ]
