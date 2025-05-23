#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

s3() {
    aws s3 --region "$AWS_REGION" "$@"
}

s3api() {
    aws s3api "$1" --region "$AWS_REGION" --bucket "$S3_BUCKET_NAME" "${@:2}"
}

bucket_exists() {
    s3 ls "$S3_BUCKET_NAME" &> /dev/null
}

create_bucket() {
    echo "Bucket $S3_BUCKET_NAME doesn't exist. Creating it now..."

    # create bucket
    s3api create-bucket \
        --create-bucket-configuration LocationConstraint="$AWS_REGION" \
        --object-ownership BucketOwnerEnforced

    # block public access
    s3api put-public-access-block \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

    # enable versioning for objects in the bucket 
    s3api put-bucket-versioning --versioning-configuration Status=Enabled

    # encrypt objects in the bucket
    s3api put-bucket-encryption \
      --server-side-encryption-configuration \
      '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
}

ensure_bucket_exists() {
    if bucket_exists; then
        return
    fi    
    create_bucket
}

pg_dump_database() {
    local pg_dump_args=(
        --no-owner
        --no-privileges
        --clean
        --if-exists
        --quote-all-identifiers
    )

    if [ "${EXCLUDE_HISTORICAL_DATA:-}" = "true" ]; then
        pg_dump_args+=(--exclude-table-data="public.*_historical")
    fi

    if [ "${EXCLUDE_TVO_LOG_DATA:-}" = "true" ]; then
        pg_dump_args+=(--exclude-table-data="public.tax_verification_logs")
    fi

    pg_dump "${pg_dump_args[@]}" "$DATABASE_URL"
}

upload_to_bucket() {
    # if the zipped backup file is larger than 50 GB add the --expected-size option
    # see https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html
    local backup_prefix="${PREFIX_FILE_NAME:+$PREFIX_FILE_NAME-}"
    s3 cp --expected-size=160000000000 - "s3://$S3_BUCKET_NAME/$(date +%Y/%m/%d/${backup_prefix}backup-%H-%M-%S.sql.gz)"
}

main() {
    ensure_bucket_exists
    echo "Taking backup and uploading it to S3..."
    pg_dump_database | gzip | upload_to_bucket
    echo "Done."
}

main
