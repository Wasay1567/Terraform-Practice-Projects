
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-chatapp-prod-ci-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/25"]

}

resource "azurerm_subnet" "frontend" {
  name                 = "snet-web-prod-ci-001"
  address_prefixes     = ["10.0.0.0/27"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "backend" {
  name                 = "snet-app-prod-ci-001"
  address_prefixes     = ["10.0.0.32/27"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  service_endpoints    = ["Microsoft.AzureCosmosDB"]
}

resource "azurerm_network_security_group" "frontend-nsg" {
  name                = "nsg-web-prod-ci-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "web"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ssh-access"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "backend-nsg" {
  name                = "nsg-app-prod-ci-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "app"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5001"
    source_address_prefix      = azurerm_subnet.frontend.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ssh-access"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "cosmos-chatapp-prod-ci-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  free_tier_enabled   = true
  offer_type          = "Standard"
  kind                = "MongoDB"
  capabilities {
    name = "EnableMongo"
  }
  is_virtual_network_filter_enabled = true
  virtual_network_rule {
    id                                   = azurerm_subnet.backend.id
    ignore_missing_vnet_service_endpoint = false
  }
  consistency_policy {
    consistency_level = "Session"
  }
  geo_location {
    location          = azurerm_resource_group.rg.location
    failover_priority = 0
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "public-ip-web-prod-ci-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic-frontend" {
  name                = "nic-web-prod-ci-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface" "nic-backend" {
  name                = "nic-app-prod-ci-001"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_network_interface_security_group_association" "frontend-nsg-association" {
  network_interface_id      = azurerm_network_interface.nic-frontend.id
  network_security_group_id = azurerm_network_security_group.frontend-nsg.id
}

resource "azurerm_network_interface_security_group_association" "backend-nsg-association" {
  network_interface_id      = azurerm_network_interface.nic-backend.id
  network_security_group_id = azurerm_network_security_group.backend-nsg.id
}

# 1. Backend VM (Created First)
resource "azurerm_linux_virtual_machine" "backend" {
  name                = "vm-backend-prod-ci-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic-backend.id]

  # Pass CosmosDB Connection String
  custom_data = base64encode(templatefile("${path.module}/backend-setup.tftpl", {
    mongodb_conn_string = azurerm_cosmosdb_account.cosmosdb.primary_mongodb_connection_string
  }))

  os_disk {
    name                 = "disk-backend"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("id_rsa.pub")
  }
}

# 2. Frontend VM (Created Second, Depends on Backend)
resource "azurerm_linux_virtual_machine" "frontend" {
  name                = "vm-frontend-prod-ci-001"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic-frontend.id]

  # PASS THE BACKEND PRIVATE IP HERE
  custom_data = base64encode(templatefile("${path.module}/frontend-setup.tftpl", {
    backend_private_ip = azurerm_network_interface.nic-backend.private_ip_address
  }))

  os_disk {
    name                 = "disk-frontend"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("id_rsa.pub")
  }

  # Explicit dependency to ensure Backend IP exists before Frontend starts
  depends_on = [azurerm_linux_virtual_machine.backend]
}