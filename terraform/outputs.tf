# Test comment to verify CI/CD pipeline triggers correctlyoutput "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}
output "rds_endpoint" {
  description = "RDS instance connection endpoint"
  value       = aws_db_instance.main.endpoint
}
