#!/bin/bash -x
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

ANGSTROM_SCRIPT_ID=88cadd2a520fb0b6b66e5e5d1814e8f36c75e87a
ANGSTROM_REPO_ID=7058b8b5dda8a6ce31e79c5253bb38789077c3ef
AMI_UBUNTU_10_04_64BIT=ami-fd4aa494
AMI_BEAGLEBOARD_VALIDATION=ami-954fa4fc
if [ "x$DEFAULT_AMI" = "x" ]; then DEFAULT_AMI=$AMI_BEAGLEBOARD_VALIDATION; fi
# MACH_TYPEs are m1.large, m2.4xlarge, etc.
MACH_TYPE=m1.xlarge
USER=ubuntu
DOWNLOAD_EBS=vol-08374961
ANGSTROM_EBS=vol-24fa964d
DOWNLOAD_DIR=/mnt/downloads
TMPFS_DIR=$HOME/angstrom-setup-scripts
S3_DEPLOY_DIR=/mnt/s3/deploy/`date +%Y%m%d%H%M`

THIS_FILE=$0

# Clear any local vars
AMI=""
INSTANCE=""
MACH_NAME=""

# Additional parameters for initiating host
function find-instance {
AMI=$1
if [ "x$AMI" = "x" ]; then AMI=$DEFAULT_AMI; fi
while
 [ "x$INSTANCE" == "x" ]
do
 #ec2-describe-instances | tee $INSTANCES;
 ec2-describe-instances > $INSTANCES;
 INSTANCE=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print("$1") && exit 0;' $INSTANCES`
 MACH_NAME=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print("$2") && exit 0;' $INSTANCES`
done
echo "INSTANCE=$INSTANCE";
echo "MACH_NAME=$MACH_NAME";
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
find-instance $AMI
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

function remote {
find-instance $AMI
ssh -i $KEYPAIR_FILE $USER@$MACH_NAME 'mkdir -p $HOME/secret; chmod 700 $HOME/secret'
scp -i $KEYPAIR_FILE $EC2_CERT $USER@$MACH_NAME:secret/cert.pem
scp -i $KEYPAIR_FILE $EC2_PRIVATE_KEY $USER@$MACH_NAME:secret/pk.pem
scp -i $KEYPAIR_FILE $HOME/secret/setup_env.sh $USER@$MACH_NAME:secret/setup_env.sh
scp -i $KEYPAIR_FILE $THIS_FILE $USER@$MACH_NAME:ec2build.sh
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
sudo aptitude install python-xcbgen -y
}

# target local
function install-oe {
mkdir -p $HOME/angstrom-setup-scripts
sudo mount -t ramfs -o size=10G ramfs $HOME/angstrom-setup-scripts
sudo chown ubuntu.ubuntu $HOME/angstrom-setup-scripts
git clone git://gitorious.org/angstrom/angstrom-setup-scripts.git
cd $HOME/angstrom-setup-scripts
git checkout -b install $ANGSTROM_SCRIPT_ID
./oebb.sh config beagleboard
./oebb.sh update
perl -pe 's/^(#)?PARALLEL_MAKE\s*=\s*"-j\d+"/PARALLEL_MAKE = "-j60"/' -i.bak $HOME/angstrom-setup-scripts/build/conf/local.conf
perl -pe 's/BB_NUMBER_THREADS\s*=\s*"\d+"/BB_NUMBER_THREADS = "4"/' -i.bak2 $HOME/angstrom-setup-scripts/build/conf/local.conf
}

# target local
function oebb {
cd $HOME/angstrom-setup-scripts
./oebb.sh $1 $2 $3 $4 $5 $6 $7 $8 $9
}

function create-download-ebs {
# VOLUME  vol-10402d79    10              us-east-1c      creating        2010-07-14T08:21:14+0000
#DOWNLOAD_EBS=`ec2-create-volume -s 10 -z us-east-1c | perl -ne '/^VOLUME\s+(\S+)\s+/ && print "$1"'`
DOWNLOAD_EBS=`ec2-create-volume -s 10 -z us-east-1c | perl -ne '/^VOLUME\s+(\S+)\s+/ && print "$1"'`
echo DOWNLOAD_EBS=$DOWNLOAD_EBS
}

function get-volume-status {
#ec2-describe-volumes | tee $VOLUMES;
ec2-describe-volumes > $VOLUMES;
#VOLUME  vol-b629ccdf    200             us-east-1c      in-use
VOLUME_STATUS=`perl -ne '/^VOLUME\s+'${EBS_VOLUME}'\s+\S+\s+(snap\S+\s+)?+\S+\s+(\S+)/ && print "$2"' $VOLUMES`
if [ "$VOLUME_STATUS" = "in-use" ]; then
 #ATTACHMENT      vol-f0402d99    i-2fd61c45      /dev/sdd        attaching       2010-07-14T08:53:30+
 VOLUME_STATUS=`perl -ne '/^ATTACHMENT\s+'${EBS_VOLUME}'\s+'${INSTANCE}'\s+\S+\s+(\S+)/ && print "$1"' $VOLUMES`
fi
echo VOLUME_STATUS=$VOLUME_STATUS
}

function attach-ebs-ami {
EBS_VOLUME=$1
DEVICE=$2
AMI=$3
find-instance $AMI
VOLUME_STATUS=
while
 [ ! "$VOLUME_STATUS" = "available" ]
do
 get-volume-status
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
 [ ! "$VOLUME_STATUS" = "attached" ]
do
 get-volume-status
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
sudo mkdir -p $DIRNAME
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
rsync -a /mnt/angstrom/* $HOME/angstrom-setup-scripts/
}

function preserve-angstrom {
rsync -a $HOME/angstrom-setup-scripts/* /mnt/angstrom/
}

function rsync-downloads-to-s3 {
rsync -a $HOME/angstrom-setup-scripts/sources/downloads /mnt/s3/downloads
}

function rsync-downloads-from-s3 {
rsync -a /mnt/s3/downloads $HOME/angstrom-setup-scripts/sources/downloads
}

function mount-tmp {
mkdir -p $TMPFS_DIR
sudo mount -t tmpfs -o size=30G,nr_inodes=30M,noatime,nodiratime tmpfs $TMPFS_DIR
sudo chown ubuntu.ubuntu $TMPFS_DIR
}

# http://xentek.net/articles/448/installing-fuse-s3fs-and-sshfs-on-ubuntu/
function enable-s3fuse {
cd $HOME
sudo aptitude install build-essential libcurl4-openssl-dev libxml2-dev libfuse-dev comerr-dev libfuse2 libidn11-dev libkadm55 libkrb5-dev libldap2-dev libselinux1-dev libsepol1-dev pkg-config fuse-utils sshfs -y
wget http://s3fs.googlecode.com/files/s3fs-r177-source.tar.gz
tar xzvf s3fs-r177-source.tar.gz
cd ./s3fs
sudo make
sudo make install
sudo perl -pe 's/^#user_allow_other/user_allow_other/' -i.bak /etc/fuse.conf
}

function remove-s3fuse-source {
cd $HOME
rm -rf s3fs
}

function mount-s3 {
sudo mkdir -p /mnt/s3
sudo modprobe fuse
sudo s3fs beagleboard-validation -o accessKeyId=$AWS_ID -o secretAccessKey=$AWS_PASSWORD -o use_cache=/tmp -o default_acl="public-read" -o allow_other /mnt/s3
}

# target local
# takes about 16 minutes
function bundle-vol {
IMAGE_NAME=beagleboard-validation-`date +%Y%m%d`
echo IMAGE_NAME=$IMAGE_NAME
sudo mkdir -p $DOWNLOAD_DIR
sudo chown ubuntu.ubuntu $DOWNLOAD_DIR
mkdir -p $TMPFS_DIR
sudo mv /mnt/$IMAGE_NAME $IMAGE_NAME.$$
sudo ec2-bundle-vol -c $EC2_CERT -k $EC2_PRIVATE_KEY -u $EC2_ID -r x86_64 -d /mnt -e /mnt,/home/ubuntu/secret,$DOWNLOAD_DIR,$TMPFS_DIR -p $IMAGE_NAME
ec2-upload-bundle -b $S3_BUCKET -m /mnt/$IMAGE_NAME.manifest.xml -a $AWS_ID -s $AWS_PASSWORD
ec2-register -n $IMAGE_NAME $S3_BUCKET/$IMAGE_NAME.manifest.xml
}

SD_IMG=beagleboard-validation-`date +%Y%m%d%H%M`.img
VFAT_LOOP=/dev/loop0
VFAT_TARGET=/mnt/sd_image1
VOL_LABEL=BEAGLE

CYL=16
HEADS=255
SECTOR_SIZE=512
SECTOR_PER_TRACK=63
BS_SIZE=`echo $HEADS \* $SECTOR_PER_TRACK \* $SECTOR_SIZE | bc`
BS_CNT=$CYL
IMG_SIZE=`echo $BS_SIZE \* $BS_CNT | bc`
FS1_OFFSET=`echo $SECTOR_SIZE \* $SECTOR_PER_TRACK | bc`
FS1_PARTITION_SIZE=15
FS1_SECTOR_CNT=`echo $FS1_PARTITION_SIZE \* $HEADS \* $SECTOR_PER_TRACK | bc`
FS1_SIZE=`echo $FS1_SECTOR_CNT \* $SECTOR_SIZE | bc` 

function enable-sd {
sudo aptitude install bc -y
#sudo sh -c 'echo "'${VFAT_LOOP}' '${VFAT_TARGET}' vfat user 0 0" >> /etc/fstab'
sudo mkdir -p $VFAT_TARGET
}

function sd-create-image {
sudo umount $VFAT_LOOP
sudo losetup -d $VFAT_LOOP
sudo rm -f $SD_IMG $SD_IMG.gz /tmp/$SD_IMG /tmp/$SD_IMG.gz
sudo dd if=/dev/zero of=/tmp/$SD_IMG bs=$BS_SIZE count=$BS_CNT
# the format for sfdisk is
# <start>,<size>,<id>,<bootable>
sudo sfdisk -C $CYL -H $HEADS -S $SECTOR_PER_TRACK -D /tmp/$SD_IMG <<EOF
,$FS1_PARTITION_SIZE,0x0c,*
EOF
sudo sh -c 'fdisk -l -u /tmp/'$SD_IMG' > '$SD_IMG'.txt'
}

function build-sd {
sudo mkdir -p $S3_DEPLOY_DIR/sd/
pushd $S3_DEPLOY_DIR/sd/
sd-create-image
DEPLOY_DIR=$HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/deploy/glibc/images/beagleboard
sudo cp $DEPLOY_DIR/MLO-beagleboard MLO
sudo cp $DEPLOY_DIR/u-boot-beagleboard.bin u-boot.bin
sudo cp $DEPLOY_DIR/uImage-beagleboard.bin uImage
sudo cp $DEPLOY_DIR/beagleboard-test-image-beagleboard.ext2.gz ramdisk.gz
sudo cp $DEPLOY_DIR/uboot-beagleboard-validation-boot.cmd.scr boot.scr
sudo cp $DEPLOY_DIR/uboot-beagleboard-validation-user.cmd.scr user.scr
sudo cp /mnt/s3/scripts/list.html .
FILES="MLO u-boot.bin uImage ramdisk.gz boot.scr user.scr"
sudo sh -c "md5sum $FILES > md5sum.txt"
sudo losetup -v -o $FS1_OFFSET $VFAT_LOOP /tmp/$SD_IMG
sudo mkfs.vfat $VFAT_LOOP -n $VOL_LABEL -F 32 120456
sudo mount $VFAT_LOOP $VFAT_TARGET
sudo cp -R $FILES md5sum.txt $VFAT_TARGET/
mount
ls -l $VFAT_TARGET/
sudo losetup $VFAT_LOOP
sudo umount $VFAT_LOOP
sudo losetup -d $VFAT_LOOP
sudo sh -c "gzip -c /tmp/$SD_IMG > $SD_IMG.gz"
sudo sh -c "gunzip -c $SD_IMG.gz > $SD_IMG"
popd
}

# about 30-40 minutes
function build-beagleboard-validation-ami {
DEFAULT_AMI=$AMI_UBUNTU_10_04_64BIT
run-ami
remote enable-oe
remote enable-s3fuse
remote enable-sd
remote enable-ec2
remote bundle-vol
halt-ami
}

function rsync-deploy {
mkdir -p $S3_DEPLOY_DIR
cp /mnt/s3/scripts/list.html $S3_DEPLOY_DIR/
rsync -a $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/deploy/glibc $S3_DEPLOY_DIR
}

function build-image {
# about 5 minutes
if [ ! -x $HOME/angstrom-setup-scripts/oebb.sh ]; then install-oe; fi
if [ ! -x $VFAT_TARGET ]; then enable-sd; fi
# I could never get the EBS volumes to mount in testing
#remote restore-angstrom
#remote mount-download-ebs
if [ ! -x /mnt/s3/scripts/ec2build.sh ]; then mount-s3; fi
#rsync-downloads-from-s3
# about 20 seconds
oebb update commit $ANGSTROM_REPO_ID
# about 90-120 minutes
oebb bitbake beagleboard-test-image
# about 90 seconds
build-sd
# only about 5 minutes if there aren't many updates
#rsync-downloads-to-s3
# about 50-70 minutes
rsync-deploy
}

# host-only
# about 200-250 minutes total
function run-build {
DEFAULT_AMI=$AMI_BEAGLEBOARD_VALIDATION
find-instance $DEFAULT_AMI
# run-ami takes about 4 minutes
if [ "x$INSTANCE" = "x" ]; then run-ami; fi
add-sshkey-ami
remote build-image
#halt-ami
}

time $*

