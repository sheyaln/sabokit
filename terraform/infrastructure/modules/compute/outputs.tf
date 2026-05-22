# Output IP address and instance information
output "ip_address" {
  description = "Public IP address of the instance"
  value       = scaleway_instance_ip.this.address
}

output "private_ip" {
  description = "Private network IPv4 address of the instance"
  # private_ips contains both IPv4 and IPv6; filter for IPv4 (contains dots)
  value = try(
    [for ip in scaleway_instance_server.this.private_ips : ip.address if can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", ip.address))][0],
    null
  )
}

output "instance_id" {
  description = "ID of the instance"
  value       = scaleway_instance_server.this.id
}

output "instance_name" {
  description = "Name of the instance"
  value       = scaleway_instance_server.this.name
}
