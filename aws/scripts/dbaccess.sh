#/bin/bash

aws secretsmanager create-secret --name "eventsDb"  --secret-string '{"dbUser":"events_user", "dbPassword":"somepass123", "dbName":"events_db" }' --region eu-west-1 --add-replica-regions Region=eu-west-2 --no-cli-pager 