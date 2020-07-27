provider "aws" {
  region                  = "ap-south-1"
  profile                 = "ankita127singh"
}


resource "aws_s3_bucket" "sb4" {
  bucket = "s4bucket918-72"
  acl    = "private"

  tags = {
    Name        = "Terra-bucket"
    Environment = "Dev"
  }
}



resource "aws_s3_bucket_public_access_block" "sbb" {

   depends_on = [
    aws_s3_bucket.sb4,
  ]
  
  bucket = aws_s3_bucket.sb4.id
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true
}



resource "aws_security_group" "sc7" {
  name        = "sc7"
  description = "created using terraform"
  vpc_id      = "vpc-089fcabd1c222262c"

  ingress {
    description = "ssh inbound rule using terraform"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }

  ingress {
    description = "http inbound rule using terraform"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }

  ingress {
    description = "custom tcp inbound rule using terraform"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }
  
  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks=["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sc7"
  }
}



resource "aws_key_pair" "TK3" {
  key_name   = "TK3"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEA4u7diIn9xz4yqlecyA1ep6Y0ERczDnVFW12Y71YgTlgt8FwXxLyFUGZKPvs41Ul3uGwZT26WBU1YyLkBvEIi0lNtClYhqw2B3Cp7PJStG+wHoV2b5ob23kdv5K0S7zq0ZY6XG1Gmu9ZwXYntawAST2O82NB2xPyFvGHw0w8fj16otPMuCWp4lv3LKwpaPsxrcLCUlqGjrkIcaQEWJWoNDza2ewJyRCs3mZELgEfmOQ6GrJOMtXs/KUczvgjtr71QYLsrk3NEn+z2T0bT0/68AH2CSQKIHWILjmltgkBObymHooCxwSsowK8aznnfRAcD/LlLLA9yoHenHNmMwX/eoQ== rsa-key-20200715"
}



resource "aws_efs_file_system" "efs1" {

  depends_on = [
    aws_security_group.sc7,
  ]
  
  creation_token = "TEFS_1"

  tags = {
    Name = "TEFS_1"
  }
}




resource "aws_efs_mount_target" "mt1" {
 
  depends_on = [
    aws_efs_file_system.efs1,
  ]
  file_system_id = aws_efs_file_system.efs1.id
  subnet_id      = "subnet-0258c7030e68c2273"
  security_groups = [aws_security_group.sc7.id]
}





resource "aws_instance"  "i2" {

   depends_on = [
    aws_efs_mount_target.mt3,
	aws_cloudfront_distribution.sbc,
  ]
  
  ami           = "ami-005956c5f0f757d37"
  instance_type = "t2.micro"
  key_name	= "TK3"
  security_groups =  [ "sc7" ] 
  availability_zone = "ap-south-1a"
  
  user_data = <<-EOF
		 #!/bin/bash
		 sudo yum install -y amazon-efs-utils
		 sudo yum install -y nfs-utils
		 file_system_id_1="${aws_efs_file_system.efs1.id}"
         mkdir /var/www
		 mkdir /var/www/html
         mount -t efs $file_system_id_1:/ /var/www/html
		 echo $file_system_id_1:/ /var/www/html efs defaults,_netdev 0 0 >> /etc/fstab
	EOF
	
  tags = {
    Name = "Terraos_2"
  }
}




locals {
  s3_origin_id = aws_s3_bucket.sb4.bucket
}

resource "aws_cloudfront_distribution" "sbc" {
	
	 depends_on = [
   aws_s3_bucket_object.sbo,
  ]
  
  origin {
    domain_name = "${aws_s3_bucket.sb4.bucket}.s3.amazonaws.com"
    origin_id   = aws_s3_bucket.sb4.bucket

    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/ETBJK5YQVCXVO"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = ""
  default_root_object = ""
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.sb4.bucket

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Environment = "TerraCloud"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}




resource "aws_s3_bucket_policy" "sbps" {

  depends_on = [
   aws_s3_bucket_public_access_block.sbb,
  ]
  
  bucket = aws_s3_bucket.sb4.id
  policy = <<EOF
{
  "Version": "2008-10-17",
    "Id": "PolicyForCloudFrontPrivateContent",
    "Statement": [
        {
            "Sid": "1",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity E3NRGG0HS1Z25F"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.sb4.bucket}/*"
        }
    ]
}
EOF
}




resource "aws_s3_bucket_object" "sbo" {

  depends_on = [
   aws_s3_bucket_policy.sbps,
  ]
  
  bucket = aws_s3_bucket.sb4.id
  key    = "s3upload2.jpg"
  source = "/Users/KIIT/Desktop/image.jpg"
  content_type = "image/jpeg"
  content_disposition = "inline"
}




resource "null_resource" "nullresource"  {

 depends_on = [
   aws_instance.i2,
  ]

    connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/KIIT/Desktop/mykey.pem")
    host     = aws_instance.i2.public_ip
  }

provisioner "remote-exec" {

    inline = [
      "sudo yum install httpd  php git -y",
	  "sudo service httpd start",
	  "sudo service httpd enabled",
      "sudo rm -rf /var/www/html",
      "sudo git clone  https://github.com/ankita127singh/lwcloudtask /var/www/html",
	  "sudo sed -i 's/old_domain/${aws_cloudfront_distribution.sbc.domain_name}/g' /var/www/html/file.html" 
    ]
  }
}




resource "null_resource" "ncl"  {


depends_on = [
    null_resource.nullresource,
  ]

	provisioner "local-exec" {
	    command = "chrome  http://${aws_instance.i2.public_ip}/file.html"
  	}
}
