variable "aws_region" {
  description = "AWS region to deploy instances in"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of the AWS EC2 key pair"
  type        = string
  default     = "labxpMobile"
}
