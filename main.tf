#Define the provider
provider "aws" {
    region = "ap-south-1"
}

#Create a virtual network
resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "MY_VPC"
    }
}

#Create your application segment
resource "aws_subnet" "my_app-subnet" {
    tags = {
        Name = "APP_Subnet"
    }
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "ap-south-1a"
    depends_on= [aws_vpc.my_vpc]

}

#Create your db segment
resource "aws_subnet" "my_db-subnet" {
    tags = {
        Name = "DB_Subnet"
    }
    vpc_id = aws_vpc.my_vpc.id
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = false
    availability_zone = "ap-south-1b"
    depends_on= [aws_vpc.my_vpc]

}

#Define routing table
resource "aws_route_table" "my_route-table" {
    tags = {
        Name = "MY_Route_table"

    }
     vpc_id = aws_vpc.my_vpc.id
}

#Associate subnet with routing table
resource "aws_route_table_association" "App_Route_Association" {
  subnet_id      = aws_subnet.my_app-subnet.id
  route_table_id = aws_route_table.my_route-table.id
}

#Create internet gateway for servers to be connected to internet
resource "aws_internet_gateway" "my_IG" {
    tags = {
        Name = "MY_IGW"
    }
     vpc_id = aws_vpc.my_vpc.id
     depends_on = [aws_vpc.my_vpc]
}

#Add default route in routing table to point to Internet Gateway
resource "aws_route" "default_route" {
  route_table_id = aws_route_table.my_route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.my_IG.id
}


#Create a security group
resource "aws_security_group" "App_SG" {
    name = "App_SG"
    description = "Allow Web inbound traffic"
    vpc_id = aws_vpc.my_vpc.id
    ingress  {
        protocol = "tcp"
        from_port = 80
        to_port  = 80
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress  {
        protocol = "tcp"
        from_port = 22
        to_port  = 22
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress  {
       protocol = "-1"
       from_port = 0
       to_port  = 0
       cidr_blocks = ["0.0.0.0/0"]
    }
}

#Create a security group for DB Server
resource "aws_security_group" "DB_SG" {
    name = "DB_SG"
    description = "Allow Web inbound traffic"
    vpc_id = aws_vpc.my_vpc.id
    ingress  {
        protocol = "tcp"
        from_port = 3306
        to_port  = 3306
        security_groups = [ aws_security_group.App_SG.id ]
    }

    ingress  {
        protocol = "tcp"
        from_port = 22
        to_port  = 22
        security_groups = [ aws_security_group.App_SG.id ]
    }

    egress  {
       protocol = "-1"
       from_port = 0
       to_port  = 0
       cidr_blocks = ["0.0.0.0/0"]
    }
}

#Create a private key which can be used to login to the webserver
resource "tls_private_key" "Web-Key" {
  algorithm = "RSA"
}

#Save public key attributes from the generated key
resource "aws_key_pair" "App-Instance-Key" {
  key_name   = "Web-key"
  public_key = tls_private_key.Web-Key.public_key_openssh
}

#Save the key to your local system
resource "local_file" "Web-Key" {
    content     = tls_private_key.Web-Key.private_key_pem
    filename = "Web-Key.pem"
}

#Create your webserver instance
resource "aws_instance" "Web" {
    ami = "ami-000cbce3e1b899ebd"
    instance_type = "t2.micro"
    tags = {
        Name = "WebServer1"
    }
    count =1
    subnet_id = aws_subnet.my_app-subnet.id
    key_name = "Web-key"
    security_groups = [aws_security_group.App_SG.id]

}

resource "aws_instance" "DB" {
    ami = "ami-0019ac6129392a0f2"
    instance_type = "t2.micro"
    tags = {
        Name = "DBServer1"
    }
    count =1
    subnet_id = aws_subnet.my_db-subnet.id
    key_name = "Web-key"
    security_groups = [aws_security_group.DB_SG.id]

}

#Create Elastic IP
resource "aws_eip" "EIP" {
 depends_on = [aws_internet_gateway.my_IG]
}

#Create Nat Gateway
resource "aws_nat_gateway" "NAT_GW" {
  allocation_id = aws_eip.EIP.id
  subnet_id     = aws_subnet.my_app-subnet.id
  depends_on = [aws_eip.EIP]
}

#Create Private route table
resource "aws_route_table" "Private_RT" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT_GW.id
  }
  tags = {
    Name = "Private-route-table"
}
}

#Associate Private Route table with DB subnet
resource "aws_route_table_association" "Route_Update_Private" {
  subnet_id      = aws_subnet.my_db-subnet.id
  route_table_id = aws_route_table.Private_RT.id
}


resource "null_resource" "Copy_Key_EC2" {
   depends_on = [aws_instance.Web]
  provisioner "local-exec" {
       command = "scp -o StrictHostKeyChecking=no -i Web-Key.pem Web-Key.pem bitnami@${aws_instance.Web[0].public_ip}:/home/bitnami"
  }
}

resource "null_resource" "running_the_website" {
    depends_on = [aws_instance.DB,aws_instance.Web]
    provisioner "local-exec" {
    command = "start chrome ${aws_instance.Web[0].public_ip}"
  }
}
