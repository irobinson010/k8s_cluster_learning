resource "aws_iam_role" "k8s_ssm_role" {
  name = "k8s_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "k8s_ssm_attach" {
  role       = aws_iam_role.k8s_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_instance_profile" "k8s_ssm_profile" {
  name = "k8s-ssm-profile"
  role = aws_iam_role.k8s_ssm_role.name
}
