provider "aws" {
  region     = "ap-south-1"
  profile    = "IAMUSER"
}

resource "aws_security_group" "security_group" {
   name = "task_security"
  description = "Allow TLS inbound traffic"


  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
   ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


resource "aws_instance" "instance1" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "newkey"
  security_groups = [ "task_security" ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/DELL/Downloads/newkey.pem")
    host     = aws_instance.instance1.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "os1"
  }

}

/*resource "aws_ebs_volume" "taskvolume" {
  availability_zone = aws_instance.instance1.availability_zone
  size              = 1

  tags = {
    Name = "ebs_volume"
  }
}

resource "aws_volume_attachment" "attachment" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.taskvolume.id}"
  instance_id = "${aws_instance.instance1.id}"
   force_detach = true
}

resource "null_resource" "null1"  {

depends_on = [
    aws_volume_attachment.attachment,
  ]


  

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/deepikarao17/cloud_terraform.git  /var/www/html/"
    ]
  }
}
*/

resource "aws_efs_file_system" "EFS_CREATE" {
  creation_token = "EFS_CREATE"

  tags = {
    Name = "EFS_CREATE"
  }
depends_on = [
aws_instance.instance1
]
}

resource "aws_efs_mount_target" "EFS_MOUNT_TARGET" {
  file_system_id = "${aws_efs_file_system.EFS_CREATE.id}"
  subnet_id      = "${aws_instance.instance1.subnet_id}"
 security_groups = ["${aws_security_group.security_group.id}"]


depends_on = [
aws_efs_file_system.EFS_CREATE,aws_instance.instance1,aws_security_group.security_group
]
}


#To mount EFS volume

resource "null_resource" "nullremote" {
 depends_on = [
  aws_efs_mount_target.EFS_MOUNT_TARGET,
 ]
 
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/DELL/Downloads/newkey.pem")
    host     = aws_instance.instance1.public_ip
  }

 provisioner "remote-exec" {
  inline = [
   "sudo mount -t nfs4 ${aws_efs_mount_target.EFS_MOUNT_TARGET.ip_address}:/ /var/www/html/",
   "sudo rm -rf /var/www/html/*",
   "sudo git clone https://github.com/deepikarao17/cloud_terraform.git /var/www/html/"
  ]
 }
}
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "bucket601"
  acl    = "public-read"

  tags = {
    Name        = "My bucket2"
  }
}


resource "aws_s3_bucket_object" "object1" {
  bucket = aws_s3_bucket.s3_bucket.bucket
  key    = "cloud.jpg"
  source = "C:/Users/DELL/Desktop/terra/firstcode/cloud.jpg"
  content_type = "image/jpeg"
}


data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.s3_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.s3_bucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
    }
  }
}



resource "aws_s3_bucket_policy" "policy" {
  bucket = "${aws_s3_bucket.s3_bucket.id}"
  policy = "${data.aws_iam_policy_document.s3_policy.json}"
}



resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Cretae origin access identity"
}
locals {
  s3_origin_id = "myS3Origin"
}



resource "aws_cloudfront_distribution" "distribution" {
depends_on = [aws_s3_bucket_object.object1,]
  origin {
    domain_name = aws_s3_bucket.s3_bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
   
s3_origin_config {
  origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
}
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN distribution"
  #default_root_object = "index.html"

 # enabled             = true
#  is_ipv6_enabled     = true
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "null2"  {

depends_on = [aws_cloudfront_distribution.distribution,]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/DELL/Downloads/newkey.pem")
    host     = aws_instance.instance1.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo su <<\"EOF\" ",
	"sudo echo <img src='https://${aws_cloudfront_distribution.distribution.domain_name}/${aws_s3_bucket_object.object1.key}' width='200' height='200' /> /var/www/html",
	"sudo systemctl restart httpd"
      
    ]
  }
}

resource "null_resource" "null3"  {
depends_on = [null_resource.null2,]


provisioner "local-exec" {
 command = " start chrome ${aws_instance.instance1.public_ip}"
}
}