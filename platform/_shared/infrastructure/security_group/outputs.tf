output "id" {
  description = "ID of the security group."
  value       = scaleway_instance_security_group.this.id
}

output "name" {
  description = "Name of the security group."
  value       = scaleway_instance_security_group.this.name
}
