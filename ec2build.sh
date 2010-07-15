#!/bin/bash
# This file is based on:
#  http://code.google.com/p/maemo-sdk-image/
#  http://forum.nginx.org/read.php?26,12659,13302

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

KEYPAIR=ec2build-keypair
KEYPAIR_FILE=$HOME/secret/$KEYPAIR.txt
INSTANCES=$HOME/ec2build-instances.txt
VOLUMES=$HOME/ec2build-volumes.txt

AMI_UBUNTU_10_04_64BIT=ami-fd4aa494
AMI_BEAGLEBOARD=ami-e00de889
AMI_BEAGLEBOARD_VALIDATION=ami-f0917a99
#DEFAULT_AMI=$AMI_BEAGLEBOARD
#DEFAULT_AMI=$AMI_UBUNTU_10_04_64BIT
DEFAULT_AMI=$AMI_BEAGLEBOARD_VALIDATION
#MACH_TYPE=m1.large
MACH_TYPE=m2.4xlarge
USER=ubuntu
#DOWNLOAD_EBS=vol-f0402d99
DOWNLOAD_EBS=vol-7ca3ce15
ANGSTROM_EBS=vol-1adcb173
#DOWNLOAD_DIR=$HOME/angstrom-setup-scripts/sources/downloads
#TMPFS_DIR=$HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1
DOWNLOAD_DIR=/mnt/downloads
TMPFS_DIR=$HOME/angstrom-setup-scripts

THIS_FILE=$0

# Clear any local vars
AMI=

# Additional parameters for initiating host
function find-instance {
AMI=$1
if [ "x$AMI" = "x" ]; then AMI=$DEFAULT_AMI; fi
if [ "x$INSTANCE" = "x" ];
then
 #ec2-describe-instances | tee $INSTANCES;
 ec2-describe-instances > $INSTANCES;
 INSTANCE=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print "$1"' $INSTANCES`
 MACH_NAME=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print "$2";' $INSTANCES`
fi
echo INSTANCE=$INSTANCE;
echo MACH_NAME=$MACH_NAME;
}

function make-keypair {
#ec2-delete-keypair $KEYPAIR
ec2-add-keypair $KEYPAIR > $KEYPAIR_FILE
chmod 600 $KEYPAIR_FILE
}

function run-ami {
AMI=$1
if [ "x$AMI" = "x" ]; then AMI=$DEFAULT_AMI; fi
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

function add-sshkey-ami {
AMI=$1
find-instance $AMI
mkdir -p $HOME/.ssh
touch $HOME/.ssh/known_hosts
chmod 644 $HOME/.ssh/known_hosts
PKEY=`grep $MACH_NAME $HOME/.ssh/known_hosts`
if [ "x$PKEY" = "x" ]
then
 echo "Adding $MACH_NAME to known hosts"
 ssh-keyscan -t rsa $MACH_NAME >> $HOME/.ssh/known_hosts
fi
}

function ssh-ami {
AMI=$1
find-instance $AMI
add-sshkey-ami
ssh -i $KEYPAIR_FILE $USER@$MACH_NAME $2 $3 $4 $5 $6 $7 $8 $9
}

function copy-files {
find-instance $AMI
ssh -i $KEYPAIR_FILE $USER@$MACH_NAME 'mkdir -p $HOME/secret; chmod 700 $HOME/secret'
scp -i $KEYPAIR_FILE $EC2_CERT $USER@$MACH_NAME:secret/cert.pem
scp -i $KEYPAIR_FILE $EC2_PRIVATE_KEY $USER@$MACH_NAME:secret/pk.pem
scp -i $KEYPAIR_FILE $HOME/secret/setup_env.sh $USER@$MACH_NAME:secret/setup_env.sh
scp -i $KEYPAIR_FILE $THIS_FILE $USER@$MACH_NAME:ec2build.sh
}

function remote {
copy-files
ssh-ami $AMI ./ec2build.sh $1 $2 $3 $4 $5 $6 $7
}

function halt-ami {
AMI=$1
find-instance $AMI
ec2-terminate-instances $INSTANCE;
}

# target local
function enable-ec2 {
# These are apparently non-free apps
sudo perl -pe 's/universe$/universe multiverse/' -i.bak /etc/apt/sources.list
sudo aptitude install ec2-api-tools ec2-ami-tools -y
}

# target local
function disable-dash {
sudo aptitude install expect -y
expect -c 'spawn sudo dpkg-reconfigure -freadline dash; send "n\n"; interact;'
}

# target local
function enable-oe {
cd $HOME
disable-dash
sudo aptitude install sed wget cvs subversion git-core \
 coreutils unzip texi2html texinfo libsdl1.2-dev docbook-utils \
 gawk python-pysqlite2 diffstat help2man make gcc build-essential g++ \
 desktop-file-utils chrpath -y
sudo aptitude install libxml2-utils xmlto python-psyco -y
mkdir -p $HOME/angstrom-setup-scripts
sudo mount -t ramfs -o size=10G ramfs $HOME/angstrom-setup-scripts
sudo chown ubuntu.ubuntu $HOME/angstrom-setup-scripts
git clone git://gitorious.org/angstrom/angstrom-setup-scripts.git
cd $HOME/angstrom-setup-scripts
./oebb.sh config beagleboard
./oebb.sh update
perl -pe 's/^(#)?PARALLEL_MAKE\s*=\s*"-j\d+"/PARALLEL_MAKE = "-j60"/' -i.bak $HOME/angstrom-setup-scripts/build/conf/local.conf
perl -pe 's/BB_NUMBER_THREADS\s*=\s*"\d+"/BB_NUMBER_THREADS = "3"/' -i.bak2 $HOME/angstrom-setup-scripts/build/conf/local.conf
}

# target local
function oebb {
cd $HOME/angstrom-setup-scripts
./oebb.sh $1 $2 $3 $4 $5 $6 $7 $8 $9
}

# host-only
function remote-oebb {
remote oebb $1 $2 $3 $4 $5 $6 $7 $8
}

# host-only
function build-default {
#remote-oebb bitbake console-image
remote-oebb bitbake beagleboard-demo-image
}

function create-download-ebs {
# VOLUME  vol-10402d79    10              us-east-1c      creating        2010-07-14T08:21:14+0000
#DOWNLOAD_EBS=`ec2-create-volume -s 10 -z us-east-1c | perl -ne '/^VOLUME\s+(\S+)\s+/ && print "$1"'`
DOWNLOAD_EBS=`ec2-create-volume -s 10 -z us-east-1b | perl -ne '/^VOLUME\s+(\S+)\s+/ && print "$1"'`
echo DOWNLOAD_EBS=$DOWNLOAD_EBS
}

function attach-ebs-ami {
EBS_VOLUME=$1
DEVICE=$2
AMI=$3
find-instance $AMI
VOLUME_STATUS=
while
 [ ! "x$VOLUME_STATUS" = "xavailable" ]
do
 #ec2-describe-volumes | tee $VOLUMES;
 ec2-describe-volumes > $VOLUMES;
 #VOLUME  vol-b629ccdf    200             us-east-1c      in-use
 VOLUME_STATUS=`perl -ne '/^VOLUME\s+'${EBS_VOLUME}'\s+\S+\s+(snap\S+\s+)?+\S+\s+(\S+)/ && print "$2"' $VOLUMES`
 echo VOLUME_STATUS=$VOLUME_STATUS
done
ec2-attach-volume $EBS_VOLUME -i $INSTANCE -d $DEVICE
}

# target local
function format-ebs-ami {
EBS_VOLUME=$1
DEVICE=$2
AMI=$3
find-instance $AMI
VOLUME_STATUS=
while
 [ ! "x$VOLUME_STATUS" = "xattached" ]
do
 #ec2-describe-volumes | tee $VOLUMES;
 ec2-describe-volumes > $VOLUMES;
 #ATTACHMENT      vol-f0402d99    i-2fd61c45      /dev/sdd        attaching       2010-07-14T08:53:30+
 VOLUME_STATUS=`perl -ne '/^ATTACHMENT\s+'${EBS_VOLUME}'\s+'${INSTANCE}'\s+\S+\s+(\S+)/ && print "$1"' $VOLUMES`
 echo VOLUME_STATUS=$VOLUME_STATUS
done
sudo mkfs.ext3 $DEVICE -F
}

function mount-ebs-ami {
EBS_VOLUME=$1
DEVICE=$2
DIRNAME=$3
AMI=$4
find-instance $AMI
VOLUME_STATUS=
while
 [ ! "x$VOLUME_STATUS" = "xattached" ]
do
 #ec2-describe-volumes | tee $VOLUMES;
 ec2-describe-volumes > $VOLUMES;
 #ATTACHMENT      vol-f0402d99    i-2fd61c45      /dev/sdd        attaching       2010-07-14T08:53:30+
 VOLUME_STATUS=`perl -ne '/^ATTACHMENT\s+'${EBS_VOLUME}'\s+'${INSTANCE}'\s+\S+\s+(\S+)/ && print "$1"' $VOLUMES`
 echo VOLUME_STATUS=$VOLUME_STATUS
done
mkdir -p $DIRNAME
sudo mount $DEVICE $DIRNAME
}

function create-download-ebs {
attach-ebs-ami $DOWNLOAD_EBS /dev/sdd
format-ebs-ami $DOWNLOAD_EBS /dev/sdd 
}

function mount-download-ebs {
attach-ebs-ami $DOWNLOAD_EBS /dev/sdd
mount-ebs-ami $DOWNLOAD_EBS /dev/sdd $DOWNLOAD_DIR
sudo chown ubuntu.ubuntu $DOWNLOAD_DIR
}

function restore-angstrom {
attach-ebs-ami $ANGSTROM_EBS /dev/sde
mount-ebs-ami $ANGSTROM_EBS /dev/sde /mnt/angstrom
sudo chown ubuntu.ubuntu /mnt/angstrom
mkdir -p $HOME/angstrom-setup-scripts
sudo mount -t ramfs -o size=10G ramfs $HOME/angstrom-setup-scripts
sudo chown ubuntu.ubuntu $HOME/angstrom-setup-scripts
#cp -R /mnt/angstrom/* $HOME/angstrom-setup-scripts/
rsync -a /mnt/angstrom/* $HOME/angstrom-setup-scripts/
}

function preserve-angstrom {
#cp -R $HOME/angstrom-setup-scripts/* /mnt/angstrom/
rsync -a $HOME/angstrom-setup-scripts/* /mnt/angstrom/
}

function mount-tmp {
mkdir -p $TMPFS_DIR
sudo mount -t tmpfs -o size=30G,nr_inodes=30M,noatime,nodiratime tmpfs $TMPFS_DIR
sudo chown ubuntu.ubuntu $TMPFS_DIR
}

# http://xentek.net/articles/448/installing-fuse-s3fs-and-sshfs-on-ubuntu/
function enable-s3fuse {
sudo aptitude install build-essential libcurl4-openssl-dev libxml2-dev libfuse-dev comerr-dev libfuse2 libidn11-dev libkadm55 libkrb5-dev libldap2-dev libselinux1-dev libsepol1-dev pkg-config fuse-utils sshfs -y
wget http://s3fs.googlecode.com/files/s3fs-r177-source.tar.gz
tar xzvf s3fs-r177-source.tar.gz
cd ./s3fs
sudo make
sudo make install
sudo perl -pe 's/^#user_allow_other/user_allow_other/' -i.bak /etc/fuse.conf
}

function mount-s3 {
sudo mkdir -p /mnt/s3
sudo modprobe fuse
sudo s3fs beagleboard-validation -o accessKeyId=$AWS_ID -o secretAccessKey=$AWS_PASSWORD -o use_cache=/tmp -o allow_other /mnt/s3
}

function bundle-vol {
IMAGE_NAME=ec2build-`date +%Y%m%d`
echo IMAGE_NAME=$IMAGE_NAME
sudo ec2-bundle-vol -c $EC2_CERT -k $EC2_PRIVATE_KEY -u $EC2_ID -r x86_64 -d /mnt -e /mnt -e $HOME/secret -e $DOWNLOAD_DIR -e $TMPFS_DIR -p $IMAGE_NAME
ec2-upload-bundle -b $S3_BUCKET -m /mnt/$IMAGE_NAME.manifest.xml -a $AWS_ID -s $AWS_PASSWORD
}

function publish {
if [ "x$IMAGE_NAME" = "x" ]; then
 IMAGE_NAME=ec2build-`date +%Y%m%d`
fi
ec2-register $S3_BUCKET/$IMAGE_NAME.manifest.xml
}

$*

