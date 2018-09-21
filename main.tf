provider "aws" {
  region = "${var.region}"
}

resource "aws_key_pair" "mainkeypair" {
  key_name = "mainkeypair"
  public_key = "${file("${var.PUBLIC_KEY_PATH}")}"
}

# UNIQUE VPC

resource "aws_vpc" "mainVpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"
    enable_dns_support = "true"
    tags {
        Name = "MainVpc"
    }
}

# ------------ SUBNETS -----------------------------------

# PUBLIC SUBNETS

resource "aws_subnet" "public-1" {
    vpc_id = "${aws_vpc.mainVpc.id}"
    cidr_block = "10.0.128.0/20"
    map_public_ip_on_launch = "true"
    availability_zone = "${var.availability-zone1}"

    tags {
        Name = "public-1"
    }
}

resource "aws_subnet" "public-2" {
    vpc_id = "${aws_vpc.mainVpc.id}"
    cidr_block = "10.0.144.0/20"
    map_public_ip_on_launch = "true"
    availability_zone = "${var.availability-zone2}"

    tags {
        Name = "public-2"
    }
}

# PRIVATE SUBNETS

resource "aws_subnet" "private-1" {
    vpc_id = "${aws_vpc.mainVpc.id}"
    cidr_block = "10.0.0.0/19"
    map_public_ip_on_launch = "false"
    availability_zone = "${var.availability-zone1}"

    tags {
        Name = "private-1"
    }
}

resource "aws_subnet" "private-2" {
    vpc_id = "${aws_vpc.mainVpc.id}"
    cidr_block = "10.0.32.0/19"
    map_public_ip_on_launch = "false"
    availability_zone = "${var.availability-zone2}"

    tags {
        Name = "private-2"
    }
}

# --------- ROUTING ------------------------------

# INTERNET GATEWAY FOR PUBLIC SUBNETS

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.mainVpc.id}"

    tags {
        Name = "CommonInternetGateway"
    }
}

# ROUTE TABLE FOR PUBLIC SUBNETS (VIA INTERNET GATEWAY)

resource "aws_route_table" "public-rt" {
    vpc_id = "${aws_vpc.mainVpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.igw.id}"
    }

    tags {
        Name = "public-rt"
    }
}

# ROUTE TABLE FOR PRIVATE SUBNETS

resource "aws_route_table" "private-rt1" {
    vpc_id = "${aws_vpc.mainVpc.id}"
    
    tags {
        Name = "private-rt1"
    }
}

# ROUTE TABLES ASSOCIATIONS

resource "aws_route_table_association" "public-1-a" {
    subnet_id = "${aws_subnet.public-1.id}"
    route_table_id = "${aws_route_table.public-rt.id}"
}
resource "aws_route_table_association" "public-2-a" {
    subnet_id = "${aws_subnet.public-2.id}"
    route_table_id = "${aws_route_table.public-rt.id}"
}
resource "aws_route_table_association" "private-1-a" {
    subnet_id = "${aws_subnet.private-1.id}"
    route_table_id = "${aws_route_table.private-rt1.id}"
}
resource "aws_route_table_association" "private-1-b" {
    subnet_id = "${aws_subnet.private-2.id}"
    route_table_id = "${aws_route_table.private-rt1.id}"
}

# ---------- SECURITY GROUPS ---------------------------------

# SECURITY GROUP FOR PUBLIC MACHINES (ELB AND FRONTEND SERVERS IN PUBLIC SUBNETS)

resource "aws_security_group" "frontend" {
  vpc_id = "${aws_vpc.mainVpc.id}"
  name = "frontend"
  description = "Incoming ssh, ping and http; all outgoing"
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags {
    Name = "frontend-server"
  }
}

# SECURITY GROUP FOR BASTION

resource "aws_security_group" "bastion" {
  vpc_id = "${aws_vpc.mainVpc.id}"
  name = "bastion"
  description = "Incoming ssh and ping; all outgoing"
  egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags {
    Name = "bastion"
  }
}

# SECURITY GROUP FOR BACKEND PRIVATE MACHINES

resource "aws_security_group" "backend" {
  vpc_id = "${aws_vpc.mainVpc.id}"
  name = "backend"
  description = "Only traffic from bastions SG: ssh (configuration) and ping (monitoring)"  
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = ["${aws_security_group.bastion.id}"]
  }

  ingress {
    from_port = 8
    to_port = 0
    protocol = "icmp"
    security_groups = ["${aws_security_group.bastion.id}"]
  }

  tags {
    Name = "backend"
  }
}

# ---------- SCALABILITY ---------------------------

# LOAD BALANCER FOR PUBLIC SUBNETS

resource "aws_elb" "elb" {
  name = "mainBalancer"
  security_groups = ["${aws_security_group.frontend.id}"]
  subnets = ["${aws_subnet.public-1.id}","${aws_subnet.public-2.id}"]
  internal = false

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = 80
    instance_protocol = "http"
  }
}

# AUTO SCALING GROUPS FOR FRONTEND SERVERS (ONE ASG FOR EVERY SUBNET)

resource "aws_autoscaling_group" "frontend-servers" {
  launch_configuration = "${aws_launch_configuration.frontend-servers.id}"
  vpc_zone_identifier = ["${aws_subnet.public-1.id}", "${aws_subnet.public-2.id}"]

  min_size = 2
  max_size = 4

  load_balancers = ["${aws_elb.elb.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "frontend-servers"
    propagate_at_launch = true
  }
}

# ------ INSTANCES ------------------------------------------

# FRONTEND SERVERS CONFIGURATION

resource "aws_launch_configuration" "frontend-servers" {
  image_id = "${var.frontend-ami-id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.frontend.id}"]
  key_name = "${aws_key_pair.mainkeypair.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

# BASTION (ONLY ONE IN ONE PUBLIC SUBNET - NO REPLICATION NEEDED)

resource "aws_instance" "bastion" {
  ami = "${var.bastion-ami-id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public-1.id}"
  vpc_security_group_ids = ["${aws_security_group.bastion.id}"]
  key_name = "${aws_key_pair.mainkeypair.key_name}"
  tags {
    Name = "bastion"
  }
}

# BACKEND INSTANCES

resource "aws_instance" "backend-1" {
  ami = "${var.backend-ami-id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private-1.id}"
  vpc_security_group_ids = ["${aws_security_group.backend.id}"]
  key_name = "${aws_key_pair.mainkeypair.key_name}"
  tags {
    Name = "backend-1"
  }
}

resource "aws_instance" "backend-2" {
  ami = "${var.backend-ami-id}"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private-2.id}"
  vpc_security_group_ids = ["${aws_security_group.backend.id}"]
  key_name = "${aws_key_pair.mainkeypair.key_name}"
  tags {
    Name = "backend-2"
  }
}
