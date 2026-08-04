#!/bin/sh

# -----------------------------------------------------------------------------
# Configuration & Paths
# -----------------------------------------------------------------------------
DB_DIR="$HOME/.omniroute"
DB_PATH="$DB_DIR/storage.sqlite"
HASH_FILE="/tmp/omniroute_db.md5"
S3_PATH="s3://${R2_BUCKET_NAME}/storage.sqlite"

# Ensure database directory exists
mkdir -p "$DB_DIR"

# Configure AWS CLI for Cloudflare R2
aws configure set default.s3.region auto
aws configure set aws_access_key_id "${R2_ACCESS_KEY_ID}"
aws configure set aws_secret_access_key "${R2_SECRET_ACCESS_KEY}"

# -----------------------------------------------------------------------------
# 1. Restoration Phase
# -----------------------------------------------------------------------------
echo "[INIT] Attempting to restore database from Cloudflare R2..."
aws s3 cp "$S3_PATH" "$DB_PATH" --endpoint-url "https://${R2_ENDPOINT}" || echo "[INIT] No existing DB found on R2. Starting with fresh DB."

# Store initial MD5 checksum
if [ -f "$DB_PATH" ]; then
    md5sum "$DB_PATH" | awk '{ print $1 }' > "$HASH_FILE"
fi

# -----------------------------------------------------------------------------
# 2. Application Launch
# -----------------------------------------------------------------------------
echo "[INIT] Starting OmniRoute application..."
npm start &
APP_PID=$!

# -----------------------------------------------------------------------------
# Helper: Backup Logic with MD5 Checksum Optimization
# -----------------------------------------------------------------------------
backup_db() {
    if [ ! -f "$DB_PATH" ]; then
        return
    fi

    CURRENT_HASH=$(md5sum "$DB_PATH" | awk '{ print $1 }')
    OLD_HASH=""
    if [ -f "$HASH_FILE" ]; then
        OLD_HASH=$(cat "$HASH_FILE")
    fi

    if [ "$CURRENT_HASH" != "$OLD_HASH" ]; then
        echo "[BACKUP] Database mutation detected. Uploading to Cloudflare R2..."
        aws s3 cp "$DB_PATH" "$S3_PATH" --endpoint-url "https://${R2_ENDPOINT}"
        echo "$CURRENT_HASH" > "$HASH_FILE"
        echo "[BACKUP] Upload completed successfully."
    else
        echo "[BACKUP] No database changes detected. Skipping R2 upload."
    fi
}

# -----------------------------------------------------------------------------
# 3. Graceful Shutdown Handler (SIGTERM)
# -----------------------------------------------------------------------------
trap 'echo "[SHUTDOWN] SIGTERM received. Executing final database backup..."; backup_db; kill -TERM $APP_PID; wait $APP_PID' TERM

# -----------------------------------------------------------------------------
# 4. Background Backup Daemon (5-minute loop)
# -----------------------------------------------------------------------------
while true; do
    sleep 300
    backup_db
done &

# Wait for the main process
wait $APP_PID
