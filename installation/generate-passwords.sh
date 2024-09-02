#!/bin/bash

# Generate a random password
generate_password() {
    openssl rand -base64 32
}

# Generate passwords for all services
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_REPLICATION_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)
MINIO_ACCESS_KEY=$(generate_password)
MINIO_SECRET_KEY=$(generate_password)

echo "PostgreSQL Password: $POSTGRES_PASSWORD"
echo "PostgreSQL Replication Password: $POSTGRES_REPLICATION_PASSWORD"
echo "Redis Password: $REDIS_PASSWORD"
echo "MinIO Access Key: $MINIO_ACCESS_KEY"
echo "MinIO Secret Key: $MINIO_SECRET_KEY"