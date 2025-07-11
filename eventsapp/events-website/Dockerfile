FROM node:slim
RUN ls
COPY  eventsapp/events-website/app /app/
WORKDIR /app
RUN npm install
CMD ["node", "server.js"]
