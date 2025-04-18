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
    echo "get_backup start"
    backup_key=$(get_most_recent_backup_key)
    echo "Backup key: $backup_key"
    s3 cp --expected-size=160000000000 "s3://$S3_BUCKET_NAME/$backup_key" backup.sql.gz
    echo "get_backup end"
}

restore_database_from_backup() {
    echo "restore_database_from_backup start"
    gunzip < backup.sql.gz | psql "$DATABASE_URL"
    rm backup.sql.gz
    echo "restore_database_from_backup end"
}

create_remix_role() {
    echo "create_remix_role start"
    # Check if role exists
    if ! psql "$DATABASE_URL" -tAc "SELECT 1 FROM pg_roles WHERE rolname='remix'" | grep -q 1; then
        psql "$DATABASE_URL" -c "CREATE ROLE remix WITH LOGIN PASSWORD '$DATABASE_REMIX_USER_PASSWORD';"
        psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO remix;"
        psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO remix;"
    else
        echo "Role 'remix' already exists, skipping creation"
    fi
    echo "create_remix_role end"
}

main() {
    echo "main start"
    cd /var/data
    get_backup
    restore_database_from_backup
    create_remix_role
    echo "main end"
}

main
