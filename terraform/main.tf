provider "aws" {
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
  tags = { Name = "bastion-sg" }
}

resource "aws_security_group" "mongo_sg" {
  name        = "mongo-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow SSH from bastion and MongoDB port"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mongo-sg" }
}

resource "aws_instance" "bastion" {
  ami                    = var.bastion_ami
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.ssh_key_name

  tags = { Name = "bastion-host" }
}

resource "aws_instance" "mongo" {
  ami                    = var.mongo_ami
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.mongo_sg.id]
  key_name               = var.ssh_key_name

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "${path.module}/../ansible"
      cat > "${path.module}/../ansible/inventory.ini" <<EOF
[mongo]
mongo1 ansible_host=${self.private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${var.private_key_path} ansible_ssh_common_args='-o ProxyCommand="ssh -i ${var.private_key_path} -W %h:%p ubuntu@${aws_instance.bastion.public_ip}"'
EOF
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  tags = { Name = "mongo-server" }
}
