variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "ap-south-2"
}

variable "project_name" {
  description = "Name prefix used for tagging all resources"
  type        = string
  default     = "three-tier-webapp"
}
variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}
