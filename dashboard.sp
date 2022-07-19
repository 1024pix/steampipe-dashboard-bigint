query "freshping_paused" {
  description = "All freshpings checks are paused"
  sql         = <<-EOQ
    select
      'Freshping monitoring' as label,
      case
        when count(*) = 0 then 'Paused'
        else 'Not paused'
      end as value,
      case
        when count(*) = 0 then 'ok'
        else 'alert'
      end as type
    from
      freshping_check
    where
      status != 'PS'
  EOQ
}
query "is_app_in_maintenance" {
  description = "Is the app in maintenance"
  sql         = <<-EOQ
    select
      $1 as label,
      case
        when response_status_code = 503 then 'En maintenance'
        else 'Running'
      end as value,
      case
        when response_status_code = 503  then 'ok'
        else 'alert'
      end as type
    from
      net_http_request
    where
      url = $2
  EOQ

  param "app_label" {
    description = "The app label"
  }
  param "app_url" {
    description = "The app url"
  }
}
query "is_app_down" {
  description = "Is the app has all containers down"
  sql         = <<-EOQ
    select
      $1 as label,
      case
        when sum(c.amount) = 0 then 'Down'
        else 'Running (' || sum(c.amount)  ||')'
      end as value,
      case
        when sum(c.amount) = 0 then 'ok'
        else 'alert'
      end as type
    from
      scalingo_app a
    join
      scalingo_container c on c.app_name = a.name
    where
      a.name = $2;
  EOQ

  param "app_label" {
    description = "The app label"
  }
  param "app_name" {
    description = "The scalingo app name"
  }
}

query "connection_number" {
  description = "Number of connections to postgres"
  sql = <<-EOQ
    select
     'Nombre de connexions '|| $1 as label,
      attributes['data']['database_stats']['current_connections'] as value
    from
       datadog_log_event
    where
      query = 'service:pix-db-stats-production @event:db-metrics @app:' || $2
    order by
      timestamp desc
    limit 1
  EOQ

  param "app_label" {
    description = "The app label"
  }

  param "app_name" {
    description = "The scalingo app name"
  }
}

query "connections_number" {
  description = "Number of connections to postgres"
  sql = <<-EOQ
    select
      to_char(timestamp, 'dd HH24:MI:SS') as "Time",
      attributes['data']['database_stats']['current_connections'] as "Nombre de connexions"
    from
       datadog_log_event
    where
      query = 'service:pix-db-stats-production @event:db-metrics @app:'|| $1
    order by
      timestamp desc
    limit 3600
  EOQ

  param "app_name" {
    description = "The scalingo app name"
  }
}

query "database_cpu" {
  description = "CPU postgres"
  sql = <<-EOQ
    select
      to_char(timestamp, 'dd HH24:MI:SS') as "Time",
      attributes['data']['cpu'] as "CPU"
    from
       datadog_log_event
    where
      query = 'service:pix-db-stats-production @event:leader-cpu @app:'|| $1
    order by
      timestamp desc
    limit 3600
  EOQ

  param "app_name" {
    description = "The scalingo app name"
  }
}


query "database_io" {
  description = "IO postgres"
  sql = <<-EOQ
    select
      to_char(timestamp, 'dd HH24:MI:SS') as "Time",
      attributes['data']['diskio_writes'] as "IO write",
      attributes['data']['diskio_reads'] as "IO reads"
    from
       datadog_log_event
    where
      query = 'service:pix-db-stats-production @event:db-diskio @app:'|| $1
    order by
      timestamp desc
    limit 3600
  EOQ

  param "app_name" {
    description = "The scalingo app name"
  }
}

chart "graph_database" {
  type = "line"

  axes {
    x {
      title {
        value  = "Time"
      }
      labels {
        display = "auto"
      }
    }
    y {
      labels {
        display = "show"
      }
    }
  }

  args = {
    app_name = "pix-api-production"
  }

  width = 4
}

dashboard "dashboard_bigint" {
  title = "Dashboard Big int"

  text {
    value = "# Suivi de la migration de la table answers en big int"
  }

  container {
    title = "Statistiques des conteneurs one-off"

    table {
      title = "Conteneurs en cours d'exécution"
      width = 4


      sql   = <<-EOQ
        with hosts as (
                  select host,
                  attributes['msg']::text as message
                  from datadog_log_event
                  where
                  query = 'service:pix-api-production host:*one\-off*'
                  and
                  timestamp >= (current_date - interval '2' minute)
        )
        select distinct(host) from hosts where message = '"alive"';
      EOQ
    }
  }

  container {
    title = "Stats connexions aux bdd"

    card {
      type = "info"
      query = query.connection_number
      icon = "link"
      args = {
        app_label = "API"
        app_name = "pix-api-production"
      }
      width = 3
    }
    card {
      type = "info"
      query = query.connection_number
      icon = "link"
      args = {
        app_label = "datawarehouse"
        app_name = "pix-datawarehouse-production"
      }
      width = 3
    }
    card {
      type = "info"
      query = query.connection_number
      icon = "link"
      args = {
        app_label = "datawarehouse-ex"
        app_name = "pix-datawarehouse-ex-production"
      }
      width = 3
    }
  }
  container {
    title = "Ici, tout doit être vert avant de démarrer la migration"

    card {
      query = query.freshping_paused
      icon = "check"
      width = 2
    }
    card {
      query = query.is_app_in_maintenance
      icon = "user"
      args = {
        app_label = "Pix App"
        app_url = "https://app.pix.fr"
      }
      width = 2
    }
    card {
      query = query.is_app_in_maintenance
      icon = "academic-cap"
      args = {
        app_label = "Pix Certif"
        app_url = "https://certif.pix.fr"
      }
      width = 2
    }
    card {
      query = query.is_app_in_maintenance
      icon = "academic-cap"
      args = {
        app_label = "Pix Orga"
        app_url = "https://orga.pix.fr"
      }
      width = 2
    }
    card {
      query = query.is_app_down
      icon = "server"
      args = {
        app_label = "Pix API"
        app_name = "pix-api-production"
      }
      width = 2
    }
    card {
      query = query.is_app_down
      icon = "chart-bar"
      args = {
        app_label = "Metabase"
        app_name = "pix-metabase-production"
      }
      width = 2
    }
    card {
      query = query.is_app_down
      icon = "database"
      args = {
        app_label = "datawarehouse"
        app_name = "pix-datawarehouse-production"
      }
      width = 2
    }
    card {
      query = query.is_app_down
      icon = "database"
      args = {
        app_label = "datawarehouse-ex"
        app_name = "pix-datawarehouse-ex-production"
      }
      width = 2
    }
    card {
      sql = <<-EOQ
        select
          'Backup activé sur pix-api-production' as label,
          case
            when periodic_backups_enabled then 'Backup activé'
            else 'Backup désactivé'
          end as value,
          case
            when not periodic_backups_enabled then 'ok'
            else 'alert'
          end as type
        from
          scalingo_addon ad
        inner join
          scalingo_database db
        on
          ad.id = db.addon_id and ad.app_name = db.app_name
        where
          ad.app_name='pix-api-production'
      EOQ
      width = 3
    }
  }

  container {
    title = "Graphs BDD api-production"

    chart {
      base = chart.graph_database
      title = "Nombre de connexions a la BDD"

      query = query.connections_number
    }

    chart {
      base = chart.graph_database
      title = "CPU BDD"

      query = query.database_cpu
    }

    chart {
      base = chart.graph_database
      title = "IO BDD"

      query = query.database_io

      series "IO write" {
        color = "red"
      }

      series "IO read" {
        color = "blue"
      }
    }
  }
}
