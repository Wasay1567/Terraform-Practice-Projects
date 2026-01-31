output "vm-public_ips" {
  value = azurerm_linux_virtual_machine.frontend.public_ip_address
}