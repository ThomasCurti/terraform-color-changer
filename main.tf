# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.9.0"
    }
  }
  required_version = ">= 0.14.9"
}
provider "azurerm" {
  features {}
}

# Generate a random integer to create a globally unique name
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Create the resource group
resource "azurerm_resource_group" "rg" {
  name     = "univ-${random_integer.ri.result}"
  location = "francecentral"
}

# Create the Linux App Service Plan
resource "azurerm_service_plan" "appserviceplan-front" {
  name                = "webapp-front-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_service_plan" "appserviceplan-back" {
  name                = "webapp-back-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "B1"
}

# Create both app services
resource "azurerm_linux_web_app" "back" {
  name                = "back-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.appserviceplan-back.id
  https_only          = true

  app_settings = {
    PORT                                    = 8080,
    WEBSITES_PORT                           = 8080,
    Kestrel__Endpoints__MyHttpEndpoint__Url = "http://0.0.0.0:8080"
  }
  site_config {
    minimum_tls_version = "1.2"
    always_on           = "true"
    application_stack {
      dotnet_version = "8.0"
    }
  }
}

resource "azurerm_linux_web_app" "front" {
  name                = "front-${random_integer.ri.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.appserviceplan-front.id
  https_only          = true

  app_settings = {
    HOST              = "0.0.0.0",
    PORT              = 3000,
    WEBSITES_PORT     = 3000,
    REACT_APP_API_URL = "https://${azurerm_linux_web_app.back.default_hostname}"
  }
  site_config {
    minimum_tls_version = "1.2"
    always_on           = "true"
    application_stack {
      node_version = "20-lts"
    }
  }
}

# Associate both to github repositories
# might timeout since this error has not been fixed https://github.com/MicrosoftDocs/azure-docs/issues/115703
resource "azurerm_app_service_source_control" "front-sourcecontrol" {
  app_id                 = azurerm_linux_web_app.front.id
  repo_url               = "https://github.com/ThomasCurti/front-color-changer.git"
  branch                 = "main"
  use_manual_integration = true
  use_mercurial          = false
}

resource "azurerm_app_service_source_control" "back-sourcecontrol" {
  app_id                 = azurerm_linux_web_app.back.id
  repo_url               = "https://github.com/ThomasCurti/back-color-changer.git"
  branch                 = "main"
  use_manual_integration = true
  use_mercurial          = false
}
