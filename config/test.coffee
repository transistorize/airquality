secrets = require('./secrets')

module.exports =
    WebService:
        prefix: 'localhost'
        port: 3000
        uploadsDir: './test/uploads'

    Postgres:
        connection: "postgres://#{secrets.PG.superuser.user}:#{secrets.PG.superuser.password}@localhost:5432/platformtest"
