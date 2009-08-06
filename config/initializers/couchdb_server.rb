
SERVER = CouchRest.new
SERVER.default_database = ["notes", Rails.env].join("_")

