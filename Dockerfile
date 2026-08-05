FROM node:20-alpine

# Install AWS CLI, coreutils (for md5sum), build tools and shell dependencies
RUN apk add --no-cache aws-cli coreutils procps python3 make g++

WORKDIR /app

# Enable legacy peer deps to bypass peer dependency mismatches (e.g. marked v18 vs v15)
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true

# Copy package files and install production dependencies
COPY package*.json ./
COPY open-sse/package.json ./open-sse/package.json
RUN npm ci --omit=dev --legacy-peer-deps --ignore-scripts

# Copy application files and scripts
COPY . .

# Make run.sh executable
RUN chmod +x ./run.sh

EXPOSE 3000

CMD ["./run.sh"]
