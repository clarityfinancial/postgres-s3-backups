#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""
PROD_DATABASE_ID="dpg-cglhh902qv24jlv6fnfg-a"

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
    s3 cp --expected-size=160000000000 "s3://$S3_BUCKET_NAME/$backup_key" -
}

create_remix_role() {
    if ! psql "$DATABASE_URL" -tAc "SELECT 1 FROM pg_roles WHERE rolname='remix'" | grep -q 1; then
        psql "$DATABASE_URL" -c "CREATE ROLE remix WITH LOGIN PASSWORD '$DATABASE_REMIX_USER_PASSWORD';"
    fi
    psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO remix;"
    psql "$DATABASE_URL" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO remix;"
}

main() {
    if [[ "$DATABASE_URL" == *"$PROD_DATABASE_ID"* ]]; then
        echo "Database is production '$PROD_DATABASE_ID', skipping steps"
    else
        psql "$DATABASE_URL" -c "DROP SCHEMA public CASCADE;CREATE SCHEMA public;"
        get_backup | gunzip | psql "$DATABASE_URL"
        create_remix_role
    fi
}

main
