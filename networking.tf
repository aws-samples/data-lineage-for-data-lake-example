################################################################
# Private VPC & VPC Endpoints
################################################################

resource "aws_vpc" "main" {
  cidr_block       = "10.1.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${local.region}.s3"
}

resource "aws_vpc_endpoint" "glue" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${local.region}.glue"
  vpc_endpoint_type = "Interface"
  subnet_ids = "${aws_subnet.subnet.*.id}"
  security_group_ids = [
    aws_security_group.sg_neptune_db.id,aws_security_group.default.id
  ]
  private_dns_enabled = true
}

resource "aws_subnet" "subnet" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = aws_vpc.main.id
  cidr_block = "10.1.${1+count.index}.0/26"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
}

resource aws_security_group "default" {
  name = "sg_default"
  ingress {
    from_port  = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = aws_vpc.main.id
}