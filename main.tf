terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.12.0"
    }
  }
}

 provider "azurerm" {
   features {}
 }

 resource "azurerm_resource_group" "test" {
   name     = "AnuragRG"
   location = "centralindia"
 }

 resource "azurerm_virtual_network" "test" {
   name                = "terraformvn"
   address_space       = ["10.0.0.0/16"]
   location            = azurerm_resource_group.test.location
   resource_group_name = azurerm_resource_group.test.name
 }

 resource "azurerm_subnet" "test" {
   name                 = "terraformsub"
   resource_group_name  = azurerm_resource_group.test.name
   virtual_network_name = azurerm_virtual_network.test.name
   address_prefixes     = ["10.0.2.0/24"]
 }

 resource "azurerm_public_ip" "test" {
   name                         = "publicIPForLB"
   location                     = azurerm_resource_group.test.location
   resource_group_name          = azurerm_resource_group.test.name
   allocation_method            = "Static"
 }

 resource "azurerm_public_ip" "vmIP" {
   count = 2
   name                         = "publicIPForVM${count.index}"
   location                     = azurerm_resource_group.test.location
   resource_group_name          = azurerm_resource_group.test.name
   allocation_method            = "Dynamic"
 }

 resource "azurerm_lb" "test" {
   #count = 2
   name                = "loadBalancer"
   location            = azurerm_resource_group.test.location
   resource_group_name = azurerm_resource_group.test.name

   frontend_ip_configuration {
     name                 = "publicIPAddress"
     public_ip_address_id = azurerm_public_ip.test.id
   }
 }

 resource "azurerm_lb_backend_address_pool" "test" {
   loadbalancer_id     = azurerm_lb.test.id
   name                = "BackEndAddrespsPool"
 }

resource "azurerm_network_security_group" "myterraformnsg" {
     name                = "AP_myNetworkSecurityGroup"
     location            = azurerm_resource_group.test.location
     resource_group_name = azurerm_resource_group.test.name
    
     security_rule {
         name                       = "RDP"
         priority                   = 101
         direction                  = "Inbound"
         access                     = "Allow"
         protocol                   = "Tcp"
         source_port_range          = "*"
         destination_port_range     = "22"
         source_address_prefix      = "*"
         destination_address_prefix = "*"
     }
    
     
 }
 resource "azurerm_network_interface" "test" {
   count               = 2
   name                = "terraformni${count.index}"
   location            = azurerm_resource_group.test.location
   resource_group_name = azurerm_resource_group.test.name

   ip_configuration {
     name                          = "testConfiguration"
     subnet_id                     = azurerm_subnet.test.id
     private_ip_address_allocation = "Dynamic"
     public_ip_address_id = element(azurerm_public_ip.vmIP.*.id, count.index)
   }
 }

 resource "azurerm_subnet_network_security_group_association" "interfaceassociation" {
     subnet_id                 = azurerm_subnet.test.id
     network_security_group_id = azurerm_network_security_group.myterraformnsg.id
 }

 resource "azurerm_network_interface_security_group_association" "nwinterfaceassociation" {
     count=2
     network_interface_id      = element(azurerm_network_interface.test.*.id, count.index)
     network_security_group_id = azurerm_network_security_group.myterraformnsg.id
 }

 resource "azurerm_managed_disk" "test" {
   count                = 2
   name                 = "datadisk_existing_${count.index}"
   location             = azurerm_resource_group.test.location
   resource_group_name  = azurerm_resource_group.test.name
   storage_account_type = "Standard_LRS"
   create_option        = "Empty"
   disk_size_gb         = "1023"
 }

 resource "azurerm_availability_set" "avset" {
   name                         = "avset"
   location                     = azurerm_resource_group.test.location
   resource_group_name          = azurerm_resource_group.test.name
   platform_fault_domain_count  = 2
   platform_update_domain_count = 2
   managed                      = true
 }

 resource "azurerm_virtual_machine" "test" {
   count                 = 2
   name                  = "terraformvm${count.index}"
   location              = azurerm_resource_group.test.location
   availability_set_id   = azurerm_availability_set.avset.id
   resource_group_name   = azurerm_resource_group.test.name
   network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
   vm_size               = "Standard_DS1_v2"

   # Uncomment this line to delete the OS disk automatically when deleting the VM
   # delete_os_disk_on_termination = true

   # Uncomment this line to delete the data disks automatically when deleting the VM
   # delete_data_disks_on_termination = true

   storage_image_reference {
     publisher = "Canonical"
     offer     = "UbuntuServer"
     sku       = "16.04-LTS"
     version   = "latest"
   }

   storage_os_disk {
     name              = "myosdisk${count.index}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }

   # Optional data disks
   storage_data_disk {
     name              = "datadisk_new_${count.index}"
     managed_disk_type = "Standard_LRS"
     create_option     = "Empty"
     lun               = 0
     disk_size_gb      = "1023"
   }

   storage_data_disk {
     name            = element(azurerm_managed_disk.test.*.name, count.index)
     managed_disk_id = element(azurerm_managed_disk.test.*.id, count.index)
     create_option   = "Attach"
     lun             = 1
     disk_size_gb    = element(azurerm_managed_disk.test.*.disk_size_gb, count.index)
   }

   os_profile {
     computer_name  = "hostname"
     admin_username = "cloudadmin"
     admin_password = "Password@123"
   }

   os_profile_linux_config {
     disable_password_authentication = false
   }

   tags = {
     environment = "staging"
   }
 }

 resource "azurerm_mysql_server" "mysqlserver" {
  name                = "ap-mysqlserver"
  location                     = azurerm_resource_group.test.location
  resource_group_name          = azurerm_resource_group.test.name

  administrator_login          = "mysqladmin"
  administrator_login_password = "Password@123"

  sku_name   = "GP_Gen5_2"
  #storage_mb = 5120
  version    = "5.7"

  #auto_grow_enabled                 = true
  #backup_retention_days             = 7
  #geo_redundant_backup_enabled      = true
  #infrastructure_encryption_enabled = true
  #public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mysql_database" "mysqldb" {
  name                = "sqldb"
  resource_group_name = azurerm_resource_group.test.name
  server_name         = azurerm_mysql_server.mysqlserver.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}