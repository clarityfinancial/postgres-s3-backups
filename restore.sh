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

    psql "$DATABASE_URL" -c "grant execute on procedure actions_sync_refresh to remix; grant execute on procedure actions_sync_refresh_by_recency to remix; grant execute on procedure actions_sync_refresh_by_bulk_action_id to remix; grant execute on procedure actions_sync_refresh_by_organization_id to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on actions_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on actions_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant execute on procedure awards_sync_refresh to remix; grant execute on procedure awards_sync_refresh_by_recency to remix; grant execute on procedure awards_sync_refresh_by_award_id to remix; grant execute on procedure awards_sync_refresh_by_organization_id to remix; grant execute on procedure awards_sync_refresh_by_household_id to remix; grant execute on procedure awards_sync_refresh_by_student_id to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on awards_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on awards_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant execute on procedure charge_requests_sync_refresh to remix; grant execute on procedure charge_requests_sync_refresh_by_recency to remix; grant execute on procedure charge_requests_sync_refresh_by_organization_id to remix; grant execute on procedure charge_requests_sync_by_ids to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on charge_requests_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on charge_requests_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant execute on procedure contracts_sync_refresh to remix; grant execute on procedure contracts_sync_refresh_by_recency to remix; grant execute on procedure contracts_sync_refresh_by_organization_id to remix; grant execute on procedure contracts_sync_refresh_by_student_id to remix; grant execute on procedure contracts_sync_by_ids to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on contracts_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on contracts_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant execute on procedure invoice_line_items_sync_refresh to remix; grant execute on procedure invoice_line_items_sync_refresh_by_recency to remix; grant execute on procedure invoice_line_items_sync_refresh_by_organization_id to remix; grant execute on procedure invoice_line_items_sync_refresh_by_student_id to remix; grant execute on procedure invoice_line_items_sync_refresh_by_academic_year_student_id to remix; grant execute on procedure invoice_line_items_sync_by_ids to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on invoice_line_items_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on invoice_line_items_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant execute on procedure students_sync_refresh to remix; grant execute on procedure students_sync_refresh_by_recency to remix; grant execute on procedure students_sync_refresh_by_organization_id to remix; grant execute on procedure students_sync_refresh_by_student_id to remix; grant execute on procedure students_sync_refresh_by_application_id to remix; grant execute on procedure students_sync_refresh_by_discount_category_id to remix; grant execute on procedure students_sync_refresh_by_grade_id to remix; grant execute on procedure students_sync_refresh_by_academic_year_student_id to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on students_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on students_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant execute on procedure students_sync_refresh to remix; grant execute on procedure students_sync_refresh_by_recency to remix; grant execute on procedure students_sync_refresh_by_organization_id to remix; grant execute on procedure students_sync_refresh_by_student_id to remix; grant execute on procedure students_sync_refresh_by_application_id to remix; grant execute on procedure students_sync_refresh_by_discount_category_id to remix; grant execute on procedure students_sync_refresh_by_grade_id to remix; grant execute on procedure students_sync_refresh_by_academic_year_student_id to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on students_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on students_sync_sequence_id_seq to remix;"

    psql "$DATABASE_URL" -c "grant execute on procedure tax_verifications_sync_refresh to remix; grant execute on procedure tax_verifications_sync_refresh_by_recency to remix; grant execute on procedure tax_verifications_sync_refresh_by_household_id to remix; grant execute on procedure tax_verifications_sync_refresh_by_organization_id to remix; grant execute on procedure tax_verifications_sync_refresh_by_tvo_id to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on tax_verifications_sync to remix;"
    psql "$DATABASE_URL" -c "grant all privileges on tax_verifications_sync_sequence_id_seq to remix;"
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
