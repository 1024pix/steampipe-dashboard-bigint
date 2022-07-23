variable "scalingo_app_where_migration_will_be_launched" {
  type    = string
  default = "pix-api-production"
}

variable "scalingo_region" {
  type    = string
  default = "osc-secnum-fr1"
}

variable "app_url_suffix" {
  type    = string
  default = ".pix.fr"
}

query "freshping_paused" {
  description = "All freshpings checks are paused"
  sql         = <<-EOQ
    select
      'Freshping monitoring' as label,
      case
        when count(*) = 0 then 'Paused'
        else 'Not paused ('|| count(*) ||')'
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
        else 'Running (HTTP ' || response_status_code || ')'
      end as value,
      case
        when response_status_code = 503  then 'ok'
        else 'alert'
      end as type,
      'https://'|| $2 || $3 as href
    from
      net_http_request
    where
      url = 'https://'|| $2 || $3
  EOQ

  param "app_label" {
    description = "The app label"
  }
  param "app_prefix" {
    description = "The app prefix url"
  }
  param "app_suffix" {
    default     = var.app_url_suffix
    description = "The app suffix url"
  }
}

query "is_app_down" {
  description = "Is the app has all containers down"
  sql         = <<-EOQ
    select
      $1 as label,
      case
        when count(*) = 0 then 'Down'
        else 'Running (' || count(*)  ||')'
      end as value,
      case
        when count(*) = 0 then 'ok'
        else 'alert'
      end as type,
      'https://dashboard.scalingo.com/apps/'|| $3 ||'/'|| $2 ||'/resources' as href
    from
      scalingo_container
    where
      app_name = $2 and type != 'one-off';
  EOQ

  param "app_label" {
    description = "The app label"
  }
  param "app_name" {
    description = "The scalingo app name"
  }
  param "region" {
    default = var.scalingo_region
    description = "The scalingo region"
  }
}

query "is_gravitee_api_down" {
  description = "Is the gravitee API stopped"
  sql         = <<-EOQ
    select
      $1 as label,
      case
        when response_status_code = 404 then 'En maintenance'
        else 'API is still running (HTTP ' || response_status_code || ')'
      end as value,
      case
        when response_status_code = 404  then 'ok'
        else 'alert'
      end as type,
      'https://gateway.pix.fr'|| $2 as href
    from
      net_http_request
    where
      url = 'https://gateway.pix.fr'|| $2
  EOQ

  param "app_label" {
    description = "The app label"
  }
  param "app_path" {
    description = "The app path"
  }
}

query "last_connection_number" {
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

  width = 6
}

dashboard "dashboard_bigint" {
  title = "Dashboard Big int"

  text {
    value = <<-EOQ
      # Suivi de la migration de la table answers en big int

      **Les requêtes ici sont cachés 2 min**.

      Ceci est le plan: [Plan de MEP Migration](https://1024pix.atlassian.net/wiki/spaces/DEV/pages/3456598017/Plan+de+MEP).

      Ce dashboard correspond au suivi de l'exécution de celui ci. Il ne fait rien à votre place, mais sur une seule page, vous savez ce qu'il se passe.

      Bonne nuit.
    EOQ
  }

  container { # Status des applications avant la MEP
    title = "1. Ici, tout doit être vert avant de démarrer la migration"

    text {
      value = <<-EOQ
        Une fois tout vert, vous pouvez passer à l'étape suivante. Tout doit rester vert pendant tout la migration. Sinon quelque chose a changé manuellement.
      EOQ
    }

    card {
      query = query.freshping_paused
      icon = "check"
      width = 3
    }
    card {
      query = query.is_app_in_maintenance
      icon = "user"
      args = {
        app_label = "Pix App"
        app_prefix = "app"
      }
      width = 3
    }
    card {
      query = query.is_app_in_maintenance
      icon = "academic-cap"
      args = {
        app_label = "Pix Certif"
        app_prefix = "certif"
      }
      width = 3
    }
    card {
      query = query.is_app_in_maintenance
      icon = "academic-cap"
      args = {
        app_label = "Pix Orga"
        app_prefix = "orga"
      }
      width = 3
    }
    card {
      query = query.is_app_down
      icon = "server"
      args = {
        app_label = "Pix API"
        app_name = var.scalingo_app_where_migration_will_be_launched
      }
      width = 3
    }
    card {
      query = query.is_app_down
      icon = "chart-bar"
      args = {
        app_label = "Metabase"
        app_name = "pix-metabase-production"
      }
      width = 3
    }
    card {
      query = query.is_app_down
      icon = "database"
      args = {
        app_label = "datawarehouse"
        app_name = "pix-datawarehouse-production"
      }
      width = 3
    }
    card {
      query = query.is_app_down
      icon = "database"
      args = {
        app_label = "datawarehouse-ex"
        app_name = "pix-datawarehouse-ex-production"
      }
      width = 3
    }
    card {
      sql = <<-EOQ
        select
          'Backup activé sur '|| $1 as label,
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
          ad.app_name=$1
      EOQ
      args = [var.scalingo_app_where_migration_will_be_launched]
      width = 3
    }
    card {
      query = query.is_gravitee_api_down
      icon = "status-online"
      args = {
        app_label = "Gravitee Pole Emploi"
        app_path = "/pole-emploi/envois"
      }
      width = 3
    }
    card {
      query = query.is_gravitee_api_down
      icon = "status-online"
      args = {
        app_label = "Gravitee LSU"
        app_path = "/organizations/1/certifications"
      }
      width = 3
    }
    card {
      query = query.is_gravitee_api_down
      icon = "status-online"
      args = {
        app_label = "Gravitee Token"
        app_path = "/api/token"
      }
      width = 3
    }
  }

  container { # Connexions BDD
    title = "2. Statistiques connexions aux bdd"

    text {
      value = <<-EOQ
        Bravo d'être arrivé jusque ici. Si tout est vert au point 1, et si la migration n'a pas commencé, les compteurs ci-dessous doivent être à **0**. Si ce n'est pas le cas, il faut trouver la raison et couper l'accès.

        Une fois l'opération lancée, on peut s'attendre a 1/2 connexions par environnement.
      EOQ
    }

    card {
      type = "info"
      query = query.last_connection_number
      icon = "link"
      args = {
        app_label = "API"
        app_name = "pix-api-production"
      }
      width = 3
    }
    card {
      type = "info"
      query = query.last_connection_number
      icon = "link"
      args = {
        app_label = "datawarehouse"
        app_name = "pix-datawarehouse-production"
      }
      width = 3
    }
    card {
      type = "info"
      query = query.last_connection_number
      icon = "link"
      args = {
        app_label = "datawarehouse-ex"
        app_name = "pix-datawarehouse-ex-production"
      }
      width = 3
    }
  }

  container { # Opérations en cours de MEP
    title = "3. OK, c'est parti"

    text {
      value = <<-EOQ
        Tout est vert, les compteurs sont a zéro, la migration peut commencer. Ici on peut suivre les conteneurs one-off qui sont en cours d'execution et le suivi du plan.

        Les étapes:

        - Altering knowledge-elements.answerId type to BIGINT - In progress: **~8h30**
        - Altering knowledge-elements.answerId type to BIGINT - Done
        - Altering flash-assessment-results.answerId type to BIGINT - In progress: **Immédiat**
        - Altering flash-assessment-results.answerId type to BIGINT - Done
        - Altering answers.id type to BIGINT - In progress: **~4h**
        - Altering answers.id type to BIGINT - Done
        - Altering answers_id_seq type to BIGINT - In progress: **Immédiat**
        - Altering answers_id_seq type to BIGINT - Done
      EOQ
    }

    table {
      title = "Conteneurs de migration en cours d'exécution (5 dernières minutes)"
      width = 8

      sql   = <<-EOQ
        with messages_alive as (
          select
            host,
            timestamp
          from
            datadog_log_event
          where
            query = 'service:'|| $1 ||' host:*one\-off* @msg:alive'
            and
            timestamp >= (current_timestamp - interval '5' minute)
          order by
            timestamp desc
        ),
        messages_not_alive as (
          select
            host,
            timestamp,
            attributes->>'msg' as message
          from
            datadog_log_event
          where
            query = 'service:'|| $1 ||' host:*one\-off* -@msg:alive'
            and
            timestamp >= (current_date - interval '1' day)
          order by
            timestamp desc
        ),
        last_timestamp as (
          select
            distinct on (host) host,
            timestamp
          from
            messages_alive
          order by
            host
        )
        select
          distinct on (lt.host) lt.host,
          lt.timestamp as last_alive_at,
          ma.message as current_step,
          ma.timestamp as current_step_started_at,
          case
            when ma.message = 'Altering knowledge-elements.answerId type to BIGINT - In progress' then '1/4'
            when ma.message = 'Altering flash-assessment-results.answerId type to BIGINT - In progress' then '2/4'
            when ma.message = 'Altering answers.id type to BIGINT - In progress' then '3/4'
            when ma.message = 'Altering answers_id_seq type to BIGINT - In progress' then '4/4'
            else 'unknown'
          end as progress
        from
          last_timestamp lt
        join
          messages_not_alive ma on ma.host = lt.host
      EOQ

      args = [var.scalingo_app_where_migration_will_be_launched]
    }

    table {
      title = "Conteneurs one-off sur api"
      width = 4
      sql   = <<-EOQ
        select
          label,
          state,
          created_at
        from
          scalingo_container
        where
          app_name=$1 and type='one-off';
      EOQ

      args = [var.scalingo_app_where_migration_will_be_launched]
    }
  }

  container { # Graphs de BDD api-production
    title = "Graphs BDD api-production"

    text {
      value = <<-EOQ
        Comme sur Datadog ou Scalingo, mais du coup ici, c'est sympa non ?
      EOQ
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

  container { # Graphs de BDD datawarehouse-production
    title = "Graphs BDD datawarehouse-production"

    text {
      value = <<-EOQ
        Tout pareil que au-dessus, mais pour datawarehouse. Trop cool non ?
      EOQ
    }

    chart {
      base = chart.graph_database
      title = "CPU BDD"
      args = {
        app_name = "pix-datawarehouse-production"
      }

      query = query.database_cpu
    }

    chart {
      base = chart.graph_database
      title = "IO BDD"
      args = {
        app_name = "pix-datawarehouse-production"
      }

      query = query.database_io

      series "IO write" {
        color = "red"
      }

      series "IO read" {
        color = "blue"
      }
    }
  }

  container {
    title = "4. C'est fini ?"

    card {
      sql = <<-EOQ
          select
            'Est ce que c''est fini?' as label,
            case
              when count(*) = 2 then 'OUI'
              when count(*) = 1 then 'Presque (1/2)'
              else 'Pas du tout'
            end as value,
            case
              when count(*) = 2 then 'start'
              when count(*) = 1 then 'emoji-happy'
              else 'emoji-sad'
            end as icon,
            case
              when count(*) = 2 then 'ok'
              when count(*) = 1 then 'info'
              else 'info'
            end as type
          from
            datadog_log_event
          where
            query = 'service:'|| $1 ||' host:*one\-off* @msg:"Altering answers_id_seq type to BIGINT - Done"'
            and
            timestamp >= (current_timestamp - interval '2' day)
      EOQ

      args = [var.scalingo_app_where_migration_will_be_launched]
    }
  }

  container { # Opération de réouverture
    title = "5. Il est temps de remonter la prod"

    text {
      value = <<-EOQ
        Bravo, la migration a fonctionné, ou peut être que non, et la nuit et la journée n'ont peut être pas été bonnes. Mais il temps de remonter la prod. Aller au point 1, et faites en sorte que tout soit rouge. Oui c'est bizarre. Mais c'est comme ça.
      EOQ
    }
  }
}
