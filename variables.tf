variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}


variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "security-lab"
}


variable "rotation_days" {
  description = "How often to automatically rotate the secret (in days)"
  type        = number
  default     = 30
}


variable "db_username" {
  description = "Database username to store in the secret"
  type        = string
  default     = "app_user"
}
