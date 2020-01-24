resource "aws_s3_bucket" "prometheus_targets" {
  bucket        = "govukobserve-targets-${var.environment}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
}

resource "aws_iam_user" "targets_writer" {
  name = "targets-writer"
  path = "/${var.environment}/"
}

resource "aws_iam_user_policy" "writer_has_full_access_to_targets_bucket" {
  name = "targets_bucket_full_access"
  user = aws_iam_user.targets_writer.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.prometheus_targets.arn}/*",
        "${aws_s3_bucket.prometheus_targets.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_s3_bucket" "prometheus_london_targets" {
  bucket        = "govukobserve-london-targets-${var.environment}"
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = true
  }
}

resource "aws_iam_user" "london_targets_writer" {
  name = "london-targets-writer"
  path = "/${var.environment}/"
}

resource "aws_iam_user_policy" "london_writer_has_full_access_to_london_targets_bucket" {
  name = "london_targets_bucket_full_access"
  user = aws_iam_user.london_targets_writer.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.prometheus_london_targets.arn}/*",
        "${aws_s3_bucket.prometheus_london_targets.arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "prometheus_has_read_access_to_targets_bucket" {
  name = "targets_bucket_read_access"
  role = aws_iam_role.prometheus_role.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.prometheus_targets.arn}/*",
        "${aws_s3_bucket.prometheus_targets.arn}",
        "${aws_s3_bucket.prometheus_london_targets.arn}/*",
        "${aws_s3_bucket.prometheus_london_targets.arn}"
      ]
    }
  ]
}
EOF
}
