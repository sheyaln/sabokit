output "id" {
  description = "ID of the private network."
  value       = scaleway_vpc_private_network.this.id
}

output "name" {
  description = "Name of the private network."
  value       = scaleway_vpc_private_network.this.name
}
