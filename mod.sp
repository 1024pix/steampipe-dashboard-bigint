mod "bigint" {
  title = "Big int"

  require {
    plugin "francois2metz/scalingo" {
      version = "0.4.0"
    }
    plugin "datadog" {
      version = "0.1.0"
    }
    plugin "net" {
      version = "0.6.0"
    }
  }
}
