FROM node:20-alpine

WORKDIR /app

RUN apk add --no-cache curl bash openssl certbot py3-pip

# Install kubectl for in-cluster pod log streaming and secret management
RUN curl -LO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/

COPY package*.json ./
RUN npm install --silent

ARG BUILD_ID=1
RUN echo "$BUILD_ID" > /app/build_id.txt

COPY . .

EXPOSE 8888

CMD ["node", "src/server.js"]
