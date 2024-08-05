terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}
provider "azurerm" {
  features {}
}
provider "tls" {}
# Resource Group
data "azurerm_resource_group" "main" {
  name     = "m346-tst-rg05"
}
 
 
 
# Virtual Network
resource "azurerm_virtual_network" "main" {
    name                = "project-vnet"
    address_space       = ["10.0.0.0/16"]
    resource_group_name = data.azurerm_resource_group.main.name
    location            = data.azurerm_resource_group.main.location
}
 
# Subnet
resource "azurerm_subnet" "main" {
    name                    = "default"
    resource_group_name     = data.azurerm_resource_group.main.name
    virtual_network_name    = azurerm_virtual_network.main.name
    address_prefixes        = ["10.0.1.0/24"]
}
 
 
# Network Security Group
resource "azurerm_network_security_group" "main" {
    name                = "project-nsg"
    location            = data.azurerm_resource_group.main.location
    resource_group_name = data.azurerm_resource_group.main.name
 
    security_rule {
        name                        = "Allow-MySQL"
        priority                    = 1001
        direction                   = "Inbound"
        access                      = "Allow"
        protocol                    = "Tcp"
        source_port_range           = "*"
        destination_port_range      = "3306"
        source_address_prefix       = "*"
        destination_address_prefix  = "*"
    }
 
  # Allow SSH
   security_rule {
    name                       = "Allow-SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    # Deny all inbound traffic as a fallback rule
   security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
 
  # Allow all outbound traffic (default rule, usually present by default)
   security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
 
# Network Interface
resource "azurerm_network_interface" "main" {
    name                = "vm-nic"
    location            = data.azurerm_resource_group.main.location
    resource_group_name = data.azurerm_resource_group.main.name
   
    ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
    }
}
 
# Public IP
resource "azurerm_public_ip" "main" {
  name                = "project-ip"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
 
 
 
 
 
 
 
# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
    name                = "project-vm"
    resource_group_name = data.azurerm_resource_group.main.name
    location            = data.azurerm_resource_group.main.location
    size                = "Standard_B1s"  # Korrigierter VM-Size
 
    admin_username      = "adminuser"
    admin_password      = "TFBern_3013"
 
    network_interface_ids = [
        azurerm_network_interface.main.id,
    ]
 
    os_disk {
        caching                 = "ReadWrite"
        storage_account_type    = "Standard_LRS"
    }
 
    source_image_reference {
        publisher   = "Canonical"
        offer       = "UbuntuServer"
        sku         = "18.04-LTS"
        version     = "latest"
    }
 
    custom_data = filebase64("${path.module}/scripts/setup_vm.sh")
 
    admin_ssh_key {
    username   = "adminuser"
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }
}
 
 
# MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "main" {
    name                = "project-mysql-server"
    location            = data.azurerm_resource_group.main.location
    resource_group_name = data.azurerm_resource_group.main.name
 
    administrator_login         = "mysqladmin"
    administrator_password      = "TFBern_3013"
    sku_name                    = "MO_Standard_E4ds_v4"
    version                     = "5.7"
   
  high_availability {
    mode        = "ZoneRedundant"
    standby_availability_zone = "2"
  }
  }
# MySQL Flexible Database
resource "azurerm_mysql_flexible_database" "main" {
    name                = "projectdb"
    resource_group_name = data.azurerm_resource_group.main.name
    server_name         = azurerm_mysql_flexible_server.main.name
    charset             = "utf8"
    collation           = "utf8_general_ci"
}
 
# App Service Plan
resource "azurerm_service_plan" "main" {
    name                = "project-appservice-plan"
    location            = data.azurerm_resource_group.main.location
    resource_group_name = data.azurerm_resource_group.main.name
    sku_name            = "F1"
    os_type             = "Linux"
}
 
# Web App (App Service)
resource "azurerm_linux_web_app" "main" {
    name                = "project-webapp"
    location            = data.azurerm_resource_group.main.location
    resource_group_name = data.azurerm_resource_group.main.name
    service_plan_id     = azurerm_service_plan.main.id
 
    app_settings = {
        "WEBSITE_RUN_FROM_PACKAGE" = "1"
    }
 
    site_config {
        always_on = false
    }
}
 
# Storage Account
resource "azurerm_storage_account" "main" {
    name                        = "storage0tfb0hori0pada"
    resource_group_name         = data.azurerm_resource_group.main.name
    location                    = data.azurerm_resource_group.main.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"
}
 
# Linux Function App
resource "azurerm_linux_function_app" "main" {
    name                        = "project-functionapp"
    location                    = data.azurerm_resource_group.main.location
    resource_group_name         = data.azurerm_resource_group.main.name
    service_plan_id             = azurerm_service_plan.main.id
    storage_account_name        = azurerm_storage_account.main.name
    storage_account_access_key  = azurerm_storage_account.main.primary_access_key
 
    app_settings = {
        "FUNCTIONS_WORKER_RUNTIME" = "dotnet"
    }
 
    site_config {}
}
 
 
# MySQL Firewall Rule for VM Access
resource "azurerm_mysql_flexible_server_firewall_rule" "vm_access" {
    name                = "AllowVMAccess"
    resource_group_name = data.azurerm_resource_group.main.name
    server_name         = azurerm_mysql_flexible_server.main.name
    start_ip_address    = "10.0.1.0"
    end_ip_address      = "10.0.1.255"
}
 
# MySQL Firewall Rule for External Access
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_external_access" {
    name                = "AllowExternalAccess"
    resource_group_name = data.azurerm_resource_group.main.name
    server_name         = azurerm_mysql_flexible_server.main.name
    start_ip_address    = "0.0.0.0"
    end_ip_address      = "255.255.255.255"
}
 
resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"
 
  response_export_values = ["publicKey", "privateKey"]
}
 
resource "random_pet" "ssh_key_name" {
  prefix    = "ssh"
  separator = ""
}
 
resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = data.azurerm_resource_group.main.location
  parent_id = data.azurerm_resource_group.main.id
}
 
 
 
output "ssh_public_key" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}
 
output "vm_public_ip" {
  value = azurerm_public_ip.main.ip_address
}
