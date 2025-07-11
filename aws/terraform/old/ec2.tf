resource "aws_instance" "ec2" {
  ami                    = "ami-09e6f87a47903347c"
  instance_type          = "t3.medium"
  associate_public_ip_address = true
  subnet_id = aws_subnet.subnet-a.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  user_data = file("startup.sh")  
  metadata_options {
   http_put_response_hop_limit = 3
  }
}

resource "aws_eip" "concourse-eip" {
  vpc = true
  instance = aws_instance.ec2.id
}
