FROM node:24-alpine

# Install AWS CLI, coreutils (for md5sum), and shell dependencies
RUN apk add --no-cache aws-cli coreutils procps

WORKDIR /app

# Enable legacy peer deps to bypass peer dependency mismatches
ENV NPM_CONFIG_LEGACY_PEER_DEPS=true
ENV PORT=3000

# Copy package files and install ALL dependencies (build tools need devDeps)
COPY package*.json ./
COPY open-sse/package.json ./open-sse/package.json
RUN npm ci --legacy-peer-deps --ignore-scripts

# Copy application files and scripts
COPY . .

# Build the Next.js standalone output (needs devDeps: typescript, tailwindcss, fumadocs-mdx, etc.)
RUN npm run build

# Set production mode for runtime (after build completes)
ENV NODE_ENV=production

# Make run.sh executable
RUN chmod +x ./run.sh

EXPOSE 3000

CMD ["./run.sh"]
