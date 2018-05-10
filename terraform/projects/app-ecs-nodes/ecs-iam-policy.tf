resource "aws_iam_instance_profile" "ecs_profile" {
  name = "${var.stack_name}-ecs-profile"
  role = "${aws_iam_role.node_iam_role.name}"
}

resource "aws_iam_role" "node_iam_role" {
  name = "${var.stack_name}-node-iam-role"
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

data "aws_iam_policy_document" "ecs_node_document" {
  statement {
    sid = "ECSNodePolicy"

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
    ]
  }
}

resource "aws_iam_policy" "ecs_node_policy" {
  name   = "${var.stack_name}_ecs_node_policy"
  path   = "/"
  policy = "${data.aws_iam_policy_document.ecs_node_document.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_node_document_policy_attachment" {
  role       = "${aws_iam_role.node_iam_role.name}"
  policy_arn = "${aws_iam_policy.ecs_node_policy.arn}"
}
