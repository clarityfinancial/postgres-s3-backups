#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

s3() {
    aws s3 --region "$AWS_REGION" "$@"
}

s3api() {
    aws s3api "$1" --region "$AWS_REGION" --bucket "$S3_BUCKET_NAME" "${@:2}"
}

get_most_recent_backup() {
    s3api list-objects --prefix "$(date +%Y/%m/%d/)" --query "Contents[?LastModified==\`$(date +%Y-%m-%d)\`].Key" --output text
}

get_backup() {
    echo "Getting most recent backup file from $S3_BUCKET_NAME ..."

    s3api get-object \
        --key "$(get_most_recent_backup)" \
        --output backup.sql.gz
}

restore_backup() {
    echo "Restoring database..."
    gunzip < backup.sql.gz | psql "$DATABASE_URL"
    echo "Done."
}

main() {
    echo "Restoring database..."
    get_backup
    restore_backup
}

main
