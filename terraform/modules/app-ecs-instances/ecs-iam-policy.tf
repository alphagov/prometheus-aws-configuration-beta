resource "aws_iam_instance_profile" "ecs_profile" {
  name = "${var.stack_name}-ecs-profile"
  role = "${aws_iam_role.instance_iam_role.name}"
}

resource "aws_iam_role" "instance_iam_role" {
  name = "${var.stack_name}-instance-iam-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_instance_document" {
  statement {
    sid = "ECSInstancePolicy"

    resources = ["*"]

    actions = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "route53:ChangeResourceRecordSets",
    ]
  }
}

resource "aws_iam_policy" "ecs_instance_policy" {
  name   = "${var.stack_name}-ecs-instance-policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.ecs_instance_document.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_document_policy_attachment" {
  role       = "${aws_iam_role.instance_iam_role.name}"
  policy_arn = "${aws_iam_policy.ecs_instance_policy.arn}"
}

resource "aws_iam_role_policy_attachment" "session_manager_access" {
  role       = "${aws_iam_role.instance_iam_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}
