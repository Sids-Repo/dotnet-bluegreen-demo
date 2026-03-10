############################

# LAUNCH TEMPLATE

############################

resource "aws_launch_template" "app" {

name_prefix   = "dotnet-template"
image_id      = "ami-0f58b397bc5c1f2e8"
instance_type = "t2.micro"

iam_instance_profile {
name = aws_iam_instance_profile.ec2_profile.name
}

network_interfaces {
associate_public_ip_address = true
security_groups             = [aws_security_group.ec2_sg.id]
}

user_data = base64encode(<<EOF
#!/bin/bash
set -e

apt-get update -y
apt-get install -y ruby wget apt-transport-https

# Install CodeDeploy Agent

cd /tmp
wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
chmod +x install
./install auto

systemctl enable codedeploy-agent
systemctl start codedeploy-agent

# Install Microsoft repo

wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

apt-get update -y

# Install ASP.NET runtime

apt-get install -y aspnetcore-runtime-6.0
apt-get install -y dotnet-runtime-6.0

# Verify installation

dotnet --info

EOF
)

}

