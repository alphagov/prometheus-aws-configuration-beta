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

data "aws_iam_policy_document" "ecs_instance_document" {
  statement {
    sid       = "ECSInstancePolicy"
    resources = ["*"]

    actions = [
      "ec2:describenetworkinterfaces",
      "ec2:attachnetworkinterface",
      "ec2:describevolumestatus",
      "ec2:describevolumes",
      "ecs:createcluster",
      "ecs:deregistercontainerinstance",
      "ecs:discoverpollendpoint",
      "ecs:poll",
      "ecs:registercontainerinstance",
      "ecs:starttelemetrysession",
      "ecs:submit*",
      "ecr:getauthorizationtoken",
      "ecr:batchchecklayeravailability",
      "ecr:getdownloadurlforlayer",
      "ecr:batchgetimage",
      "logs:createlogstream",
      "logs:putlogevents",
    ]
  }

  statement {
    resources = [
      "arn:aws:ec2:${var.aws_region}:${var.account_id}:volume/${aws_ebs_volume.prometheus_ebs_volume.id}",
      "arn:aws:ec2:${var.aws_region}:${var.account_id}:instance/*"
    ]


    actions = [
      "ec2:AttachVolume",
      "ec2:DetachVolume",
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
