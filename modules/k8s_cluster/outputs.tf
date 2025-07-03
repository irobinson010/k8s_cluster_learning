output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = [for w in aws_instance.workers : w.public_ip]
}
