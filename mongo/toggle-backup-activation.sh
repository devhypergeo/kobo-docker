#!/usr/bin/env bash


rm -f /etc/cron.d/backup_mongo_crontab
if [[ -z "${MONGO_BACKUP_SCHEDULE}" ]]; then
    echo "MongoDB automatic backups disabled."
else
    # Install cron in case if not present
    echo "Installing cron..."
    apt-get update --quiet=2 > /dev/null
    apt-get install -y cron --quiet=2 > /dev/null

    # Pass env variables to cron task
    echo "MONGO_MAJOR=${MONGO_MAJOR}" >> /etc/cron.d/backup_mongo_crontab
    echo "PUBLIC_DOMAIN_NAME=${PUBLIC_DOMAIN_NAME}" >> /etc/cron.d/backup_mongo_crontab
    echo "MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}" >> /etc/cron.d/backup_mongo_crontab
    echo "MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}" >> /etc/cron.d/backup_mongo_crontab

    # To use S3 as storage, AWS access key, secret key and bucket name must filled up
    USE_S3=1
    TRUE=1
    FALSE=0

    # Add only non-empty variable to cron tasks
    if [ -n "${AWS_ACCESS_KEY_ID}" ]; then
        echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" >> /etc/cron.d/backup_mongo_crontab
    else
        USE_S3=$FALSE
    fi

    if [ -n "${AWS_SECRET_ACCESS_KEY}" ]; then
        echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" >> /etc/cron.d/backup_mongo_crontab
    else
        USE_S3=$FALSE
    fi

    if [ -n "${BACKUP_AWS_STORAGE_BUCKET_NAME}" ]; then
        echo "BACKUP_AWS_STORAGE_BUCKET_NAME=${BACKUP_AWS_STORAGE_BUCKET_NAME}" >> /etc/cron.d/backup_mongo_crontab
    else
        USE_S3=$FALSE
    fi

    if [ -n "${AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED}" ]; then
        echo "AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED=${AWS_BACKUP_BUCKET_DELETION_RULE_ENABLED}" >> /etc/cron.d/backup_mongo_crontab
    fi
    if [ -n "${AWS_BACKUP_YEARLY_RETENTION}" ]; then
        echo "AWS_BACKUP_YEARLY_RETENTION=${AWS_BACKUP_YEARLY_RETENTION}" >> /etc/cron.d/backup_mongo_crontab
    fi
    if [ -n "${AWS_BACKUP_MONTHLY_RETENTION}" ]; then
        echo "AWS_BACKUP_MONTHLY_RETENTION=${AWS_BACKUP_MONTHLY_RETENTION}" >> /etc/cron.d/backup_mongo_crontab
    fi
    if [ -n "${AWS_BACKUP_WEEKLY_RETENTION}" ]; then
        echo "AWS_BACKUP_WEEKLY_RETENTION=${AWS_BACKUP_WEEKLY_RETENTION}" >> /etc/cron.d/backup_mongo_crontab
    fi
    if [ -n "${AWS_BACKUP_DAILY_RETENTION}" ]; then
        echo "AWS_BACKUP_DAILY_RETENTION=${AWS_BACKUP_DAILY_RETENTION}" >> /etc/cron.d/backup_mongo_crontab
    fi
    if [ -n "${AWS_MONGO_BACKUP_MINIMUM_SIZE}" ]; then
        echo "AWS_MONGO_BACKUP_MINIMUM_SIZE=${AWS_MONGO_BACKUP_MINIMUM_SIZE}" >> /etc/cron.d/backup_mongo_crontab
    fi

    if [ "$USE_S3" -eq "$TRUE" ]; then
        echo "Installing virtualenv for Mongo backup on S3..."
        apt-get install -y s3cmd --quiet=2 > /dev/null
        apt-get install -y python-virtualenv --quiet=2 > /dev/null
        virtualenv /tmp/backup-virtualenv
        . /tmp/backup-virtualenv/bin/activate
        pip install --quiet boto
        deactivate

        INTERPRETER=/tmp/backup-virtualenv/bin/python
        BACKUP_SCRIPT="/kobo-docker-scripts/backup-to-s3.py"
    else
        INTERPRETER=$(which bash)
        BACKUP_SCRIPT="/kobo-docker-scripts/backup-to-disk.bash"
    fi

    # Should we first validate the schedule e.g. with `chkcrontab`?
    echo "${MONGO_BACKUP_SCHEDULE}  root    ${INTERPRETER} ${BACKUP_SCRIPT} > /srv/logs/backup.log 2>&1" >> /etc/cron.d/backup_mongo_crontab
    echo "" >> /etc/cron.d/backup_mongo_crontab
    service cron restart
    echo "MongoDB automatic backup schedule: ${MONGO_BACKUP_SCHEDULE}"
fi
