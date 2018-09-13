#Prepare to attach role to instance
resource "aws_iam_instance_profile" "prometheus_instance_profile" {
  name = "prometheus_${var.environment}_config_reader_profile"
  role = "${aws_iam_role.prometheus_role.name}"
}

#Create role
resource "aws_iam_role" "prometheus_role" {
  name = "prometheus_profile_${var.environment}"

  assume_role_policy = "${data.aws_iam_policy_document.prometheus_assume_role_policy.json}"
}

#Create permission to assume role
data "aws_iam_policy_document" "prometheus_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

#Define the policy to attach the role too
resource "aws_iam_policy" "prometheus_instance_profile" {
  name        = "prometheus_instance_profile_${var.environment}"
  path        = "/"
  description = "This is the main profile, that has bucket permission and decribe permissions"

  policy = "${data.aws_iam_policy_document.instance_role_policy.json}"
}

#define IAM policy documention
data "aws_iam_policy_document" "instance_role_policy" {
  statement {
    sid       = "ec2Policy"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }

  statement {
    sid = "s3Bucket"

    actions = [
      "s3:Get*",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.prometheus_config.id}/*",
      "arn:aws:s3:::${aws_s3_bucket.prometheus_config.id}",
      "arn:aws:s3:::${var.targets_bucket}/*",
      "arn:aws:s3:::${var.targets_bucket}",
    ]
  }
}

#Attach policy to role
resource "aws_iam_role_policy_attachment" "iam_policy" {
  role       = "${aws_iam_role.prometheus_role.name}"
  policy_arn = "${aws_iam_policy.prometheus_instance_profile.arn}"
}
