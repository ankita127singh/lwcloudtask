

provider "aws" {
 	 region = "ap-south-1"
  	profile = "ankita127singh"
}


resource "aws_key_pair" "mykey" {
 	 key_name   = "mykey"
 	 public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAwFFgBW4DqK7RatWO7qX8sALDSnLZ/aGGUNeHcguZVALJHVmyKzKDe4R9aEgQvHleQLGffD3YWtMBVJiBPIdMg/HFze9tiEO5ALoZH4UoCvLGW0zXtTHfJDEYK0pmIxp19XhbzKCOkVUcbDtuIFluDg1Rk6ADR9/j6Gcr8Z3nz6+6DfXxWyl9Igu/Bct3S73ZkjNvVAiN0w6d9M3n4VX7CewaftJzCiYJ/c7mpnpod+6cfNumGV0KTkLoMlnCa98eCyp4m4gAi6BjpUHJJnIJflP1m7M0+YwiZrvUEfjU4qJIEgCvt9HW4ja3BijNqgP5i/ywO4c2c15zz3XWqiyqMw== rsa-key-20200614"
}


resource "aws_security_group" "sg" {
	name        = "sg"
  	description = "Allow TLS inbound traffic"
  	vpc_id      = "vpc-6de2ff05"


  	ingress {
    		description = "SSH"
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = [ "0.0.0.0/0" ]
  	}

  	ingress {
    		description = "HTTP"
    		from_port   = 80
    		to_port     = 80
    		protocol    = "tcp"
    		cidr_blocks = [ "0.0.0.0/0" ]
  	}

  	egress {
    		from_port   = 0
    		to_port     = 0
    		protocol    = "-1"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	tags = {
    		Name = "sg"
  	}
}



resource "aws_instance" "web" {
  	ami           = "ami-005956c5f0f757d37"
  	instance_type = "t2.micro"
  	key_name = "mykey"
  	security_groups = [ "sg" ]

  	tags = {
    		Name = "task1_os"
  	}

}

resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/xvds"
  volume_id   = aws_ebs_volume.esb1.id
  instance_id = aws_instance.web.id
  force_detach = true

  
}
output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "aws_s3_bucket" "mytask-bucket"{
	bucket = "mytask-bucket"
	acl = "public-read"

	
}

resource "aws_s3_bucket_object" "file_upload" {
	depends_on = [
    		aws_s3_bucket.mytask-bucket,
  	]
  	bucket = "${aws_s3_bucket.mytask-bucket.bucket}"
  	key    = "image.jpg"
  	source = "C:/Users/KIIT/Desktop/image.jpg"
	content_type = "image/jpeg"
    content_disposition = "inline"
}


locals {
  s3_origin_id = aws_s3_bucket.mytask-bucket.bucket
}

resource "aws_cloudfront_distribution" "s3_distribution" {
	depends_on = [
		aws_volume_attachment.ebs_att,
    		aws_s3_bucket_object.file_upload,
  	]

	origin {
		domain_name = "${aws_s3_bucket.mytask-bucket.bucket}.s3.amazonaws.com"
		origin_id = aws_s3_bucket.mytask-bucket.bucket 
        
        s3_origin_config{
            origin_access_identity="origin-access-identity/cloudfront/E1PUVHD7WV3G0A"
         }
        }
	enabled = true
	is_ipv6_enabled = true
        default_root_object = "file.html"
	
	restrictions {
		geo_restriction {
			restriction_type = "none"
 		 }
 	    }

	default_cache_behavior {
		allowed_methods = ["HEAD", "GET"]
		cached_methods = ["HEAD", "GET"]
                target_origin_id=aws_s3_bucket.mytask-bucket.bucket
		forwarded_values {
			query_string = false
			cookies {
				forward = "none"
			}
		}
		default_ttl = 86400
		max_ttl = 31536000
		min_ttl = 0
		viewer_protocol_policy = "redirect-to-https"
		}

	price_class = "PriceClass_All"

	 viewer_certificate {
   		 cloudfront_default_certificate = true
  	}		
}






resource "null_resource" "nullremote3"  {
connection {
    		type     = "ssh"
    		user     = "ec2-user"
   		private_key = file("C:/Users/KIIT/Desktop/mykey.pem")
    		host     ="${aws_instance.web.public_ip}"
  	}

	provisioner "remote-exec" {
    		inline = [
				"sudo yum install httpd php git -y",
				
				"sudo service httpd start",
      			"sudo mkfs.ext4  /dev/xvds -y",
      			"sudo mount  /dev/xvds  /var/www/html",
      			"sudo rm -rf /var/www/html",
      			"sudo git clone  https://github.com/ankita127singh/lwcloudtask.git    /var/www/html/",
                        "sudo sed -i 's/domain_name/${aws_cloudfront_distribution.s3_distribution.domain_name}/g' /var/www/html/file.html",
				"sudo echo ${aws_cloudfront_distribution.s3_distribution.domain_name}"
    		]
	  }
}


resource "null_resource" "nulllocal1"  {
	depends_on = [
    		null_resource.nullremote3,
  	]

	provisioner "local-exec" {
	    command = "start chrome   ${aws_instance.web.public_ip}/file.html"
  	}
}
