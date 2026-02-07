output "server_id" {
    value = azurerm_mssql_server.mssqlsrv.id
}
output "database_id" {
    value = azurerm_mssql_database.mssqldb.id
}

