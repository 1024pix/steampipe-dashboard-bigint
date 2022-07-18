query "is_app_in_maintenance" {
  description = "Is the app in maintenance"
  sql         = <<-EOQ
    select
      $1 as label,
      case
        when count(*) > 0 then 'En maintenance '
        else 'Running'
      end as value,
      case
        when count(*) > 0 then 'ok'
        else 'alert'
      end as type
    from
      scalingo_app a
    join
      scalingo_environment e on e.app_name = a.name and e.name = 'MAINTENANCE_PLANIFIEE' and e.value = 'enabled'
    where
      a.name = $2;
  EOQ

  param "app_label" {
    description = "The app label"
  }
  param "app_name" {
    description = "The app name"
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

query "connections_number" {
  description = "Number of connections to postgres"
  sql = <<-EOQ
    select
     'Nombre de connexions '|| $1  as label,
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

dashboard "dashboard_bigint" {
  title = "Dashboard Big int"

  text {
    value = "Suivi de la migration de la table answers en big int"
  }

  container {
    card {
      type = "info"
      query = query.connections_number
      args = ["api", "pix-api-production"]
      width = 3
    }
    card {
      type = "info"
      query = query.connections_number
      args = ["datawarehouse", "pix-datawarehouse-production"]
      width = 3
    }
    card {
      type = "info"
      query = query.connections_number
      args = ["dawarehouse-ex", "pix-datawarehouse-ex-production"]
      width = 3
    }
  }
  container {
    text {
      value = "Ici, tout doit être vert avant de démarrer la migration"
    }
    card {
      query = query.is_app_in_maintenance
      args = ["Pix App", "pix-app-production"]
      width = 2
    }
    card {
      query = query.is_app_in_maintenance
      args = ["Pix Certif", "pix-certif-production"]
      width = 2
    }
    card {
      query = query.is_app_in_maintenance
      args = ["Pix Orga", "pix-orga-production"]
      width = 2
    }
    card {
      query = query.is_app_down
      args = ["Pix API", "pix-api-production"]
      width = 2
    }
    card {
      query = query.is_app_down
      args = ["Metabase", "pix-metabase-production"]
      width = 2
    }
    card {
      query = query.is_app_down
      args = ["Datawarehouse-production", "pix-datawarehouse-production"]
      width = 2
    }
    card {
      query = query.is_app_down
      args = ["Datawarehouse-ex-production", "pix-datawarehouse-ex-production"]
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
    text {
      value = "Graphs BDD"
    }
    chart {
      type = "line"
      title = "Nombre de connexions a la BDD"
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
          title {
            value  = "Nombre de connexions"
          }
          labels {
            display = "show"
          }
        }
      }

      sql = <<-EOQ
        select
          to_char(timestamp, 'dd HH24:MI:SS'),
          attributes['data']['database_stats']['current_connections'] as "Nombre de connexions"
        from
           datadog_log_event
        where
          query = 'service:pix-db-stats-production @event:db-metrics @app:pix-api-production'
        order by
          timestamp desc
        limit 3600
      EOQ
    }
  }
}
