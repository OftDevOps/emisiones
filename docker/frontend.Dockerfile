FROM node:22-slim

WORKDIR /app/frontend

COPY frontend /app/frontend

CMD ["npm", "run", "dev"]
