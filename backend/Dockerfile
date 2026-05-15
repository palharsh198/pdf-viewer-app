FROM node:20

RUN apt-get update && apt-get install -y \
    poppler-utils \
    tesseract-ocr \
    libreoffice \
    ghostscript \
    graphicsmagick \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
CMD ["node", "server.js"]