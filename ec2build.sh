#!/bin/bash
# This file is based on:
#  http://developer.amazonwebservices.com/connect/message.jspa?messageID=42535#42535
#  http://blog.atlantistech.com/index.php/2006/10/04/amazon-elastic-compute-cloud-walkthrough/
#  http://developer.amazonwebservices.com/connect/entry.jspa?categoryID=116&externalID=661
#  http://overstimulate.com/articles/2006/08/24/amazon-does-it-again.html
#  http://www.howtoforge.com/amazon_elastic_compute_cloud_qemu
#  http://info.rightscale.com/2007/2/14/bundling-up-an-ubuntu-ec2-instance
#  http://repository.maemo.org/stable/3.1/INSTALL.txt
#  http://code.google.com/p/maemo-sdk-image/

# Need to get settings for
#  EC2_HOME
#  EC2_PRIVATE_KEY
#  EC2_CERT
#  EC2_ID
#  AWS_ID
#  AWS_PASSWORD
#  PATH -- must include EC2_HOME/bin
#  S3_BUCKET
source $HOME/secret/setup_env.sh

KEYPAIR=$HOME/secret/my-keypair.txt
INSTANCES=$HOME/ami-instances.txt

AMI_UBUNTU_10_04_64BIT=ami-fd4aa494
AMI_BEAGLEBOARD=ami-e00de889
DEFAULT_AMI=$AMI_UBUNTU_10_04_64BIT
#DEFAULT_AMI=$AMI_BEAGLEBOARD
MACH_TYPE=m1.large
USER=ubuntu

# Additional parameters for initiating host
function find-instance {
AMI=$1
if [ "x$AMI" == "x" ]; then AMI=$DEFAULT_AMI; fi
ec2-describe-instances | tee $INSTANCES;
INSTANCE=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print "$1"' $INSTANCES`
MACH_NAME=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print "$2";' $INSTANCES`
echo INSTANCE=$INSTANCE;
echo MACH_NAME=$MACH_NAME;
}

function make-keypair {
ec2-add-keypair ec2build-keypair > $KEYPAIR
chmod 600 $KEYPAIR
}

function run-default-ami {
run-ami $DEFAULT_AMI
}

function run-ami {
AMI=$1
if [ "x$MACH_TYPE" == "x" ];
then
ec2-run-instances $AMI -k $KEYPAIR
else
ec2-run-instances $AMI -k $KEYPAIR -t $MACH_TYPE
fi

INSTANCE=""
MACH_NAME=""
while
 [ "x$INSTANCE" == "x" ]
do
 find-instance $AMI;
done
}

function authorize-ssh {
ec2-authorize default -p 22
}

function bundle-vol {
IMAGE_NAME=$1
echo IMAGE_NAME=$IMAGE_NAME
ec2-bundle-vol -d /mnt -e /root/secret -k /root/secret/pk.pem -c /root/secret/cert.pem -u $EC2_ID -p $IMAGE_NAME
ec2-upload-bundle -b $S3_BUCKET -m /mnt/$IMAGE_NAME.manifest.xml -a $AWS_ID -s $AWS_PASSWORD
}

function remote {
find-instance $AMI
ssh -i $KEYPAIR $USER@$EC2_MACH_NAME ec2build.sh $1 $2 $3 $4 $5 $6 $7 $8 $9
}

function copy-files {
find-instance $AMI
ssh -i $KEYPAIR $USER@$EC2_MACH_NAME 'mkdir $HOME/secret; chmod 700 $HOME/secret'
scp -i $KEYPAIR $EC2_CERT $USER@$EC2_MACH_NAME:secret/cert.pem
scp -i $KEYPAIR $EC2_PRIVATE_KEY $USER@$EC2_MACH_NAME:secret/pk.pem
scp -i $KEYPAIR secret/setup_env.sh $USER@$EC2_MACH_NAME:secret/setup_env.sh
}

function halt-ami {
AMI=$1
find-instance $AMI
ec2-terminate-instances $EC2_INSTANCE;
}

function login-ami {
AMI=$1
find-instance $AMI
ssh -i $KEYPAIR $USER@$EC2_MACH_NAME
}

function publish {
ec2-register $S3_BUCKET/$1.manifest.xml
}

function enable_oe {
sudo aptitude install sed wget cvs subversion git-core \
 coreutils unzip texi2html texinfo libsdl1.2-dev docbook-utils \
 gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ \
 desktop-file-utils chrpath -y
sudo aptitude install libxml2-utils xmlto python-psyco -y
git clone git://gitorious.org/angstrom/angstrom-setup-scripts.git
cd angstrom-setup-scripts
./oebb.sh config beagleboard
./oebb.sh update
}

$*

