locals {
  environment  = "prod"
  project_name = "webapp"

  common_tags = {
    environment = local.environment
    project     = local.project_name
    managed_by  = "terraform"
  }

  name_prefix = "${local.environment}-${local.project_name}"
}

resource "azurerm_resource_group" "appgrp" {
  name     = "${local.name_prefix}-rg"
  location = local.resource_location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "app_network" {
  name                = "${local.name_prefix}-vnet"
  location            = local.resource_location
  resource_group_name = azurerm_resource_group.appgrp.name
  address_space       = local.virtual_network.address_prefixes
  tags                = local.common_tags
}

resource "azurerm_subnet" "websubnet01" {
  name                 = "${local.name_prefix}-web-subnet"
  resource_group_name  = azurerm_resource_group.appgrp.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = [local.subnets.address_prefixes[0]]
}

resource "azurerm_subnet" "appsubnet01" {
  name                 = "${local.name_prefix}-app-subnet"
  resource_group_name  = azurerm_resource_group.appgrp.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = [local.subnets.address_prefixes[1]]
}

resource "azurerm_network_interface" "webinterface01" {
  name                = "${local.name_prefix}-web-nic"
  location            = local.resource_location
  resource_group_name = azurerm_resource_group.appgrp.name

  ip_configuration {
    name                          = "web-ipconfig"
    subnet_id                     = azurerm_subnet.websubnet01.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(local.subnets.address_prefixes[0], 10)
    public_ip_address_id          = azurerm_public_ip.webip01.id
  }
  tags = local.common_tags
}

resource "azurerm_network_interface" "appinterface01" {
  name                = "${local.name_prefix}-app-nic"
  location            = local.resource_location
  resource_group_name = azurerm_resource_group.appgrp.name

  ip_configuration {
    name                          = "app-ipconfig"
    subnet_id                     = azurerm_subnet.appsubnet01.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(local.subnets.address_prefixes[1], 10)
    public_ip_address_id          = azurerm_public_ip.appip01.id
  }
  tags = local.common_tags
}

resource "azurerm_public_ip" "webip01" {
  name                = "${local.name_prefix}-web-pip"
  resource_group_name = azurerm_resource_group.appgrp.name
  location            = local.resource_location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_public_ip" "appip01" {
  name                = "${local.name_prefix}-app-pip"
  resource_group_name = azurerm_resource_group.appgrp.name
  location            = local.resource_location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_security_group" "web-app_nsg" {
  name                = "${local.name_prefix}-nsg"
  location            = local.resource_location
  resource_group_name = azurerm_resource_group.appgrp.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "173.9.131.165/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "websubnet01_webappnsg" {
  subnet_id                 = azurerm_subnet.websubnet01.id
  network_security_group_id = azurerm_network_security_group.web-app_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "appsubnet01_webappnsg" {
  subnet_id                 = azurerm_subnet.appsubnet01.id
  network_security_group_id = azurerm_network_security_group.web-app_nsg.id
}

resource "azurerm_windows_virtual_machine" "webvm01" {
  name                = "${local.name_prefix}-vm"
  resource_group_name = azurerm_resource_group.appgrp.name
  location            = local.resource_location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.webinterface01.id,
  ]

  os_disk {
    name                 = "${local.name_prefix}-vm-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  boot_diagnostics {}

  tags = local.common_tags
}

resource "azurerm_managed_disk" "datadisk01" {
  name                 = "${local.name_prefix}-vm-datadisk"
  location             = local.resource_location
  resource_group_name  = azurerm_resource_group.appgrp.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "4"

  tags = local.common_tags
}