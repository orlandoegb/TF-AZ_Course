locals {
  resource_location = "North Europe"
  virtual_network = {
    name             = "app-network"
    address_prefixes = ["10.0.0.0/16"]
  }

  subnets = {
    name             = ["websubnet01", "appsubnet01"]
    address_prefixes = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
    subnets = [
      {
        name             = "websubnet01"
        address_prefixes = "10.0.0.0/24"
      },
      {
        name             = "appsubnet01"
        address_prefixes = "10.0.1.0/24",
      }
    ]
  }
}
