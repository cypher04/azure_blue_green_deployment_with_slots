resource "azurerm_log_analytics_workspace" "log_analytics" {
    name                = "${var.project_name}-loganalytics-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name
    sku                 = "PerGB2018"
    retention_in_days   = 30
}



resource "azurerm_application_insights" "app_insights" {
    name                = "${var.project_name}-appinsights-${var.environment}"
    location            = var.location
    resource_group_name = var.resource_group_name
    application_type    = "web"
    internet_ingestion_enabled = false
    internet_query_enabled = false
}




