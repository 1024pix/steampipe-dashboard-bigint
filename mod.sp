mod "bigint" {
  title = "Big int"

  require {
    plugin "francois2metz/scalingo" {
      version = "0.7.1"
    }
    plugin "datadog" {
      version = "0.1.0"
    }
    plugin "net" {
      version = "0.6.0"
    }
    plugin "ghcr.io/francois2metz/freshping" {
      version = "0.0.2"
    }
  }
}
