FROM node:20-alpine

# Install AWS CLI, coreutils (for md5sum), build tools and shell dependencies
RUN apk add --no-cache aws-cli coreutils procps python3 make g++

WORKDIR /app

# Copy package files and install production dependencies
COPY package*.json ./
COPY open-sse/package.json ./open-sse/package.json
RUN npm ci --only=production

# Copy application files and scripts
COPY . .

# Make run.sh executable
RUN chmod +x ./run.sh

EXPOSE 3000

CMD ["./run.sh"]
