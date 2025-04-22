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

    # Grant remix the permissions it needs
    psql "$DATABASE_URL" -c "GRANT USAGE ON SCHEMA public TO remix;"
    psql "$DATABASE_URL" -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO remix;"
    psql "$DATABASE_URL" -c "GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO remix;"

    echo "Starting execute grants."
    psql "$DATABASE_URL" -c "grant execute on all functions in schema public to remix;"
    
    echo "Starting privilige grants."
    psql "$DATABASE_URL" -c "grant all privileges on actions_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on actions_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on applications_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on applications_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on awards_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on awards_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on charge_requests_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on charge_requests_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on contracts_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on contracts_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on invoice_line_items_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on invoice_line_items_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on students_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on students_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on students_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on students_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant all privileges on tax_verifications_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on tax_verifications_sync_sequence_id_seq to remix;"
}

run_post_restore_actions() {
    # Disabled celery beat tasks for controlled re-enablement
    psql "$DATABASE_URL" -c "update django_celery_beat_periodictask set enabled = false;"
}

main() {
    if [[ "$DATABASE_URL" == *"$PROD_DATABASE_ID"* ]]; then
        echo "Database is production '$PROD_DATABASE_ID', skipping steps"
    else
        psql "$DATABASE_URL" -c "DROP SCHEMA public CASCADE;CREATE SCHEMA public;"
        get_backup | gunzip | psql "$DATABASE_URL"
        create_remix_role
        run_post_restore_actions
    fi
}

main
