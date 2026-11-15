# Rails 7+ uses Zeitwerk exclusively, which would otherwise expect
# app/models/generators/{csv,json}/ to define `Csv` / `Json` rather than
# `CSV` / `JSON`.
Rails.autoloaders.main.inflector.inflect("csv" => "CSV", "json" => "JSON")
