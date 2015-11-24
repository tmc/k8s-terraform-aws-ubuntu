provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_key_pair" "kubernetes" {
  key_name   = "kubernetes-${var.CLUSTER_ID}"
  public_key = "${var.aws_key_pair_pubkey}"
}

resource "aws_eip" "kubernetes-master" {
  instance = "${aws_instance.kubernetes-master.id}"
  vpc      = true
}

module "ami-kubernetes-master" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami/ebs"
  region = "${var.aws_region}"
  distribution = "${var.KUBE_OS_DISTRIBUTION}"
  instance_type = "${var.MASTER_SIZE}"
}

resource "aws_instance" "kubernetes-master" {
  ami                         = "${module.ami-kubernetes-master.ami_id}"
  availability_zone           = "${var.aws_availability_zone}"
  instance_type               = "${var.MASTER_SIZE}"
  key_name                    = "${aws_key_pair.kubernetes.key_name}"
  subnet_id                   = "${aws_subnet.main.id}"
  vpc_security_group_ids      = ["${aws_security_group.kubernetes-master.id}"]
  associate_public_ip_address = true
  private_ip                  = "172.20.0.9"
  iam_instance_profile        = "${var.CLUSTER_ID}-master"
  user_data                   = "${template_file.user_data-master.rendered}"

  tags {
    "KubernetesCluster" = "${var.CLUSTER_ID}"
    "Role" = "${var.CLUSTER_ID}-master"
    "Name" = "${var.CLUSTER_ID}-master"
  }

  provisioner "remote-exec" {
    script = "wait_for_salt_master.sh"
    connection {
      user = "ubuntu"
    }
  }
  depends_on = ["aws_internet_gateway.gw"]  
}

resource "template_file" "user_data-master" {
  filename = "user_data-master.tpl"
  vars = {
    aws_availability_zone          = "${var.aws_availability_zone}"
    CLUSTER_ID                     = "${var.CLUSTER_ID}"
    KUBE_VERSION                   = "${var.KUBE_VERSION}"
    CLUSTER_IP_RANGE               = "${var.CLUSTER_IP_RANGE}"
    NUM_MINIONS                    = "${var.NUM_MINIONS}"
    ZONE                           = "${var.aws_availability_zone}"
    KUBE_USER                      = "${var.KUBE_USER}"
    KUBE_PASSWORD                  = "${var.KUBE_PASSWORD}"
    ENABLE_CLUSTER_MONITORING      = "${var.ENABLE_CLUSTER_MONITORING}"
    ENABLE_CLUSTER_LOGGING         = "${var.ENABLE_CLUSTER_LOGGING}"
    ENABLE_NODE_LOGGING            = "${var.ENABLE_NODE_LOGGING}"
    LOGGING_DESTINATION            = "${var.LOGGING_DESTINATION}"
    ELASTICSEARCH_LOGGING_REPLICAS = "${var.ELASTICSEARCH_LOGGING_REPLICAS}"
    ENABLE_CLUSTER_DNS             = "${var.ENABLE_CLUSTER_DNS}"
    ENABLE_CLUSTER_UI              = "${var.ENABLE_CLUSTER_UI}"
    DNS_REPLICAS                   = "${var.DNS_REPLICAS}"
    DNS_SERVER_IP                  = "${var.DNS_SERVER_IP}"
    DNS_DOMAIN                     = "${var.DNS_DOMAIN}"
    ADMISSION_CONTROL              = "${var.ADMISSION_CONTROL}"
    MASTER_IP_RANGE                = "${var.MASTER_IP_RANGE}"
    KUBELET_TOKEN                  = "${var.KUBELET_TOKEN}"
    KUBE_PROXY_TOKEN               = "${var.KUBE_PROXY_TOKEN}"
    DOCKER_STORAGE                 = "${var.DOCKER_STORAGE}"
    EXTRA_DOCKER_OPTS              = "${var.EXTRA_DOCKER_OPTS}"
  }
}

resource "aws_autoscaling_group" "kubernetes-minion-group" {
  desired_capacity          = "${var.NUM_MINIONS}"
  health_check_grace_period = 0
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.kubernetes-minion-group.name}"
  max_size                  = "${var.NUM_MINIONS}"
  min_size                  = "${var.NUM_MINIONS}"
  name                      = "${var.CLUSTER_ID}-minion-group"
  vpc_zone_identifier       = ["${aws_subnet.main.id}"]

  tag {
    key   = "KubernetesCluster"
    value = "${var.CLUSTER_ID}"
    propagate_at_launch = true
  }
  tag {
    key   = "Name"
    value = "${var.CLUSTER_ID}-minion"
    propagate_at_launch = true
  }
  tag {
    key   = "Role"
    value = "${var.CLUSTER_ID}-minion"
    propagate_at_launch = true
  }
}

module "ami-kubernetes-minions" {
  source = "github.com/terraform-community-modules/tf_aws_ubuntu_ami/ebs"
  region = "${var.aws_region}"
  distribution = "${var.KUBE_OS_DISTRIBUTION}"
  instance_type = "${var.MINION_SIZE}"
}

resource "aws_launch_configuration" "kubernetes-minion-group" {
  image_id                    = "${module.ami-kubernetes-minions.ami_id}"
  instance_type               = "${var.MINION_SIZE}"
  key_name                    = "${aws_key_pair.kubernetes.key_name}"
  associate_public_ip_address = true
  security_groups             = ["${aws_security_group.kubernetes-minion.id}"]
}

resource "template_file" "user_data-minion" {
  filename = "user_data-minion.tpl"
  vars = {
    DOCKER_STORAGE                 = "${var.DOCKER_STORAGE}"
    EXTRA_DOCKER_OPTS              = "${var.EXTRA_DOCKER_OPTS}"
  }
}


resource "aws_iam_instance_profile" "kubernetes-master" {
  name  = "${var.CLUSTER_ID}-master"
  path  = "/"
  roles = ["${var.CLUSTER_ID}-master"]
}

resource "aws_iam_instance_profile" "kubernetes-minion" {
  name  = "${var.CLUSTER_ID}-minion"
  path  = "/"
  roles = ["${var.CLUSTER_ID}-minion"]
}


resource "aws_iam_role" "kubernetes-master" {
  name         = "${var.CLUSTER_ID}-master"
  path         = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Effect": "Allow",
    "Principal": {
    "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
  ]
}
EOF
}

resource "aws_iam_role" "kubernetes-minion" {
  name         = "${var.CLUSTER_ID}-minion"
  path         = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Effect": "Allow",
    "Principal": {
    "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
  ]
}
EOF
}

resource "aws_iam_role_policy" "kubernetes-master" {
  name   = "${var.CLUSTER_ID}-master"
  role   = "${aws_iam_role.kubernetes-master.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Effect": "Allow",
    "Action": [
    "ec2:*"
    ],
    "Resource": [
    "*"
    ]
  },
  {
    "Effect": "Allow",
    "Action": [
    "elasticloadbalancing:*"
    ],
    "Resource": [
    "*"
    ]
  },
  {
    "Effect": "Allow",
    "Action": "s3:*",
    "Resource": [
    "arn:aws:s3:::kubernetes-*"
    ]
  }
  ]
}
EOF
}

resource "aws_iam_role_policy" "kubernetes-minion" {
  name   = "${var.CLUSTER_ID}-minion"
  role   = "${aws_iam_role.kubernetes-minion.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Effect": "Allow",
    "Action": "s3:*",
    "Resource": [
    "arn:aws:s3:::kubernetes-*"
    ]
  },
  {
    "Effect": "Allow",
    "Action": "ec2:Describe*",
    "Resource": "*"
  },
  {
    "Effect": "Allow",
    "Action": "ec2:AttachVolume",
    "Resource": "*"
  },
  {
    "Effect": "Allow",
    "Action": "ec2:DetachVolume",
    "Resource": "*"
  }
  ]
}
EOF
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_security_group" "kubernetes-master" {
  name        = "kubernetes-master-${var.CLUSTER_ID}"
  description = "Kubernetes security group applied to master nodes"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    "KubernetesCluster" = "${var.CLUSTER_ID}"
  }
}

resource "aws_security_group" "kubernetes-minion" {
  name        = "kubernetes-minion-${var.CLUSTER_ID}"
  description = "Kubernetes security group applied to minion nodes"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.kubernetes-master.id}"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    "KubernetesCluster" = "${var.CLUSTER_ID}"
  }
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags {
    Name = "main"
  }
}

resource "aws_route_table_association" "r" {
    subnet_id = "${aws_subnet.main.id}"
    route_table_id = "${aws_route_table.r.id}"
}

resource "aws_subnet" "main" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "172.20.0.0/24"
  availability_zone = "${var.aws_availability_zone}"

  tags {
    "KubernetesCluster" = "${var.CLUSTER_ID}"
  }
}

resource "aws_vpc" "main" {
  cidr_block       = "172.20.0.0/16"
  enable_dns_hostnames = true

  tags {
    "KubernetesCluster" = "${var.CLUSTER_ID}"
    "Name" = "kubernetes-vpc"
  }
}

