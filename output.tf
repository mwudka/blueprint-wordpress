output "public-url" {
  value = "http://${local.public-ip}"
}

output "ssh-command" {
    value = local.ssh-command
}
