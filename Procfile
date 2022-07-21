web: ./bin/steampipe dashboard --mod-install --dashboard-port $PORT --dashboard-listen network
tcp: ./bin/steampipe service start --foreground --database-port $PORT --database-listen network --database-password $STEAMPIPE_PASSWORD
