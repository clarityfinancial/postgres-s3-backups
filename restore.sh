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
    backup_key=$(get_most_recent_backup_key)
    s3 cp --quiet --expected-size=160000000000 "s3://$S3_BUCKET_NAME/$backup_key" -
}

restore_database_from_backup() {
    aws s3 cp --region "us-west-2" --expected-size=160000000000 "s3://clarity-database-backupsqa/2025/04/20/backup-12-00-41.sql.gz" | psql "$DATABASE_URL"
}

create_remix_role() {
    # Check if role exists
    if ! psql "$DATABASE_URL" -tAc "SELECT 1 FROM pg_roles WHERE rolname='remix'" | grep -q 1; then
        psql "$DATABASE_URL" -c "CREATE ROLE remix WITH LOGIN PASSWORD '$DATABASE_REMIX_USER_PASSWORD';"
        psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO remix;"
        psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO remix;"
    else
        echo "Role 'remix' already exists, skipping creation"
    fi
}

main() {
    restore_database_from_backup
    create_remix_role
}

main
