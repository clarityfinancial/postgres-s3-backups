#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

s3() {
    aws s3 --region "$AWS_REGION" "$@"
}

s3api() {
    aws s3api "$1" --region "$AWS_REGION" --bucket "$S3_BUCKET_NAME" "${@:2}"
}

get_most_recent_backup_key() {
    s3api list-objects --query 'sort_by(Contents, &LastModified)[-1].Key' --output text
}

get_backup() {
    echo "Getting backup file from $S3_BUCKET_NAME ..."
    backup_key=$(get_most_recent_backup_key)
    echo "Backup key: $backup_key"
    s3api get-object --key "$backup_key" \
        backup.sql.gz
}

restore_database_from_backup() {
    echo "Restoring database..."
    gunzip < backup.sql.gz | psql "$DATABASE_URL"
    echo "Restoration complete."
}

create_remix_role() {
    echo "Creating roles..."
    psql "$DATABASE_URL" -c "CREATE ROLE IF NOT EXISTS remix WITH LOGIN PASSWORD $DATABASE_REMIX_USER_PASSWORD;"
    psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO remix;"
    psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO remix;"
    echo "Role creation complete."
}

main() {
    echo "Restoring database..."
    get_backup
    restore_database_from_backup
    create_remix_role
    echo "Database restoration complete."
}

main
