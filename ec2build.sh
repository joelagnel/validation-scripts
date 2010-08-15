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

# These are the git commit ids we want to use to build
ANGSTROM_SCRIPT_ID=f593f1c023cd991535c748682ab21154c807385e
ANGSTROM_REPO_ID=48bd2ee153f86d36946f9ccf483d07dca1b864ec
HALT="no"

# Setup DEFAULT_AMI
# UBUNTU_10_04_64BIT AMI is the original default, but you can seed with others
AMI=ami-fd4aa494
if [ -e $HOME/ec2build-ami.sh ]; then source $HOME/ec2build-ami.sh; fi

DATE=`date +%Y%m%d%H%M`
KEYPAIR=ec2build-keypair
KEYPAIR_FILE=$HOME/secret/$KEYPAIR.txt
INSTANCES=$HOME/ec2build-instances.txt
VOLUMES=$HOME/ec2build-volumes.txt

# MACH_TYPEs are m1.large, m2.4xlarge, etc.
MACH_TYPE=m1.xlarge
DOWNLOAD_EBS=vol-08374961
ANGSTROM_EBS=vol-24fa964d
DOWNLOAD_DIR=/mnt/downloads
TMPFS_DIR=$HOME/angstrom-setup-scripts
S3_DEPLOY_DIR=/mnt/s3/deploy/$DATE

THIS_FILE=$0

# Clear any local vars
INSTANCE=""
MACH_NAME=""

# host-only
# about 200-250 minutes total
function run-build {
if [ "x$AMI" = "xami-fd4aa494" ]; then
 build-beagleboard-validation-ami
 AMI=$NEW_AMI
 echo "AMI=$NEW_AMI" > $HOME/ec2build-ami.sh
fi
if [ "x$INSTANCE" = "x" ]; then run-ami; fi
remote setup-oe
copy-ti-tools
remote build-image
halt-ami
}

function setup-tmp {
if [ "x$TMP" = "x" ]; then
 sudo mkdir -p /mnt/ubuntu-tmp
 sudo chown ubuntu.ubuntu /mnt/ubuntu-tmp
 TMP=/mnt/ubuntu-tmp
fi
}

# about 30-40 minutes
function build-beagleboard-validation-ami {
AMI=ami-fd4aa494
run-ami
remote enable-oe
remote enable-s3fuse
remote enable-ec2
remote bundle-vol
halt-ami
}

function halt-ami {
if [ "x$HALT" = "xno" ]; then
 echo "Halt is currently disabled"
else
 find-instance
 ec2-terminate-instances $INSTANCE;
 INSTANCE=""
fi
}

# run-ami takes about 4 minutes
function run-ami {
if [ ! -e $KEYPAIR_FILE ]; then make-keypair; fi
if [ "x$INSTANCE" = "x" ]; then check-instance; fi
if [ "x$INSTANCE" = "x" ]; then
 if [ "x$MACH_TYPE" = "x" ];
 then
  ec2-run-instances $AMI -k $KEYPAIR
 else
  ec2-run-instances $AMI -k $KEYPAIR -t $MACH_TYPE
 fi
 add-sshkey-ami
else
 echo "Already running instance $INSTANCE."
fi
}

function check-instance {
ec2-describe-instances > $INSTANCES;
INSTANCE=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print("$1") && exit 0;' $INSTANCES`
MACH_NAME=`perl -ne '/^INSTANCE\s+(\S+)\s+'${AMI}'\s+(\S+)\s+\S+\s+running\s+/ && print("$2") && exit 0;' $INSTANCES`
}

function make-keypair {
#ec2-delete-keypair $KEYPAIR
ec2-add-keypair $KEYPAIR > $KEYPAIR_FILE
chmod 600 $KEYPAIR_FILE
}

function add-sshkey-ami {
find-instance
mkdir -p $HOME/.ssh
touch $HOME/.ssh/known_hosts
chmod 644 $HOME/.ssh/known_hosts
PKEY=`grep $MACH_NAME $HOME/.ssh/known_hosts`
if [ "x$PKEY" = "x" ]
then
 echo "Adding $MACH_NAME to known hosts"
 # give the new instance time to start up
 sleep 10
 ssh-keyscan -t rsa $MACH_NAME >> $HOME/.ssh/known_hosts
fi
}

# Additional parameters for initiating host
function find-instance {
while
 [ "x$INSTANCE" == "x" ]
do
 check-instance
done
echo "INSTANCE=$INSTANCE";
echo "MACH_NAME=$MACH_NAME";
}

function authorize-ssh {
ec2-authorize default -p 22
}

function ssh-ami {
if [ "x$INSTANCE" = "x" ]; then run-ami; fi
ssh -i $KEYPAIR_FILE ubuntu@$MACH_NAME $1 $2 $3 $4 $5 $6 $7 $8 $9
}

function remote {
if [ "x$INSTANCE" = "x" ]; then run-ami; fi
ssh -i $KEYPAIR_FILE ubuntu@$MACH_NAME 'mkdir -p $HOME/secret; chmod 700 $HOME/secret'
scp -i $KEYPAIR_FILE $EC2_CERT ubuntu@$MACH_NAME:secret/cert.pem
scp -i $KEYPAIR_FILE $EC2_PRIVATE_KEY ubuntu@$MACH_NAME:secret/pk.pem
scp -i $KEYPAIR_FILE $HOME/secret/setup_env.sh ubuntu@$MACH_NAME:secret/setup_env.sh
scp -i $KEYPAIR_FILE $THIS_FILE ubuntu@$MACH_NAME:ec2build.sh
ssh-ami ./ec2build.sh $1 $2 $3 $4 $5 $6 $7 $8
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
sudo aptitude install ia32-libs -y
}

# target local
# about 5 minutes
function install-oe {
mkdir -p $HOME/angstrom-setup-scripts
sudo mount -t ramfs -o size=10G ramfs $HOME/angstrom-setup-scripts
sudo chown ubuntu.ubuntu $HOME/angstrom-setup-scripts
git clone git://gitorious.org/angstrom/angstrom-setup-scripts.git
cd $HOME/angstrom-setup-scripts
git checkout -b install $ANGSTROM_SCRIPT_ID
./oebb.sh config beagleboard
./oebb.sh update
perl -pe 's/^(INHERIT\s*\+=\s*"rm_work"/#$1/' -i.bak1 $HOME/angstrom-setup-scripts/build/conf/local.conf
perl -pe 's/^(#)?PARALLEL_MAKE\s*=\s*"-j\d+"/PARALLEL_MAKE = "-j60"/' -i.bak2 $HOME/angstrom-setup-scripts/build/conf/local.conf
perl -pe 's/BB_NUMBER_THREADS\s*=\s*"\d+"/BB_NUMBER_THREADS = "8"/' -i.bak3 $HOME/angstrom-setup-scripts/build/conf/local.conf
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
find-instance
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
find-instance
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
find-instance
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
mkdir -p /mnt/s3/downloads
cp /mnt/s3/scripts/list.html /mnt/s3/downloads/
rsync -a $HOME/angstrom-setup-scripts/sources/downloads/ /mnt/s3/downloads/
}

function rsync-downloads-from-s3 {
mkdir -p $HOME/angstrom-setup-scripts/sources/downloads
rsync -a /mnt/s3/downloads/ $HOME/angstrom-setup-scripts/sources/downloads/
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
sudo s3fs beagleboard-validation -o accessKeyId=$AWS_ID -o secretAccessKey=$AWS_PASSWORD -o use_cache=/mnt -o default_acl="public-read" -o allow_other /mnt/s3
}

# target local
# takes about 16 minutes
function bundle-vol {
IMAGE_NAME=beagleboard-validation-$DATE
echo IMAGE_NAME=$IMAGE_NAME
sudo mkdir -p $DOWNLOAD_DIR
sudo chown ubuntu.ubuntu $DOWNLOAD_DIR
mkdir -p $TMPFS_DIR
sudo mv /mnt/$IMAGE_NAME $IMAGE_NAME.$$
sudo ec2-bundle-vol -c $EC2_CERT -k $EC2_PRIVATE_KEY -u $EC2_ID -r x86_64 -d /mnt -e /mnt,/home/ubuntu/secret,$DOWNLOAD_DIR,$TMPFS_DIR -p $IMAGE_NAME
ec2-upload-bundle -b $S3_BUCKET -m /mnt/$IMAGE_NAME.manifest.xml -a $AWS_ID -s $AWS_PASSWORD
ec2-register -n $IMAGE_NAME $S3_BUCKET/$IMAGE_NAME.manifest.xml
#IMAGE  ami-954fa4fc    beagleboard-validation/beagleboard-validation-20100804.manifest.xml 283181587 744 available   private  x86_64 machine aki-0b4aa462
NEW_AMI=`ec2-describe-images | perl -ne '/^IMAGE\s+(\S+)\s+'${S3_BUCKET}'\/'${IMAGE_NAME}'.manifest.xml\s+/ && print("$1") && exit 0;'`
}

function sd-create-image {
IMG_NAME=$1
CYL=$2

if [ ! -e `which bc` ]; then sudo aptitude install bc -y; fi
FS1_PARTITION_SIZE=15
FS1_OFFSET=`echo 512 \* 63 | bc`
CYL_SIZE=`echo 255 \* 63 \* 512 | bc`
FS2_OFFSET=`echo $FS1_PARTITION_SIZE \* $CYL_SIZE | bc`
FS2_SIZE=`echo \( $CYL \- $FS1_PARTITION_SIZE \) \* $CYL_SIZE | bc`
IMG_SIZE=`echo $CYL \* $CYL_SIZE | bc`

setup-tmp
sudo umount /dev/loop0
sudo losetup -d /dev/loop0
sudo rm -f $IMG_NAME $IMG_NAME.gz $TMP/$IMG_NAME $TMP/$IMG_NAME.gz
dd if=/dev/zero of=$TMP/$IMG_NAME bs=$CYL_SIZE count=$CYL
# the format for sfdisk is
# <start>,<size>,<id>,<bootable>
sfdisk -C $CYL -H 255 -S 63 -D $TMP/$IMG_NAME <<EOF
,$FS1_PARTITION_SIZE,0x0c,*
,,0x83,-
EOF
sh -c "fdisk -C $CYL -l -u $TMP/$IMG_NAME > $IMG_NAME.txt"
}

function build-sd {
mkdir -p $S3_DEPLOY_DIR/sd/
sudo mkdir -p /mnt/sd_image1
sudo mkdir -p /mnt/sd_image2
pushd $S3_DEPLOY_DIR/sd/
DEPLOY_DIR=$HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/deploy/glibc/images/beagleboard
cp $DEPLOY_DIR/MLO-beagleboard MLO
cp $DEPLOY_DIR/u-boot-beagleboard.bin u-boot.bin
cp $DEPLOY_DIR/uImage-beagleboard.bin uImage
cp $DEPLOY_DIR/beagleboard-test-image-beagleboard.ext2.gz ramdisk.gz
cp $DEPLOY_DIR/beagleboard-test-image-beagleboard.cpio.gz.u-boot ramfs.img
cp $DEPLOY_DIR/uboot-beagleboard-validation-boot.cmd.scr boot.scr
cp $DEPLOY_DIR/uboot-beagleboard-validation-user.cmd.scr user.scr
cp $DEPLOY_DIR/beagleboard-demo-image-beagleboard.tar.bz2 demo-$DATE.tar.bz2
cp $THIS_FILE .
cp /mnt/s3/scripts/list.html .

FILES="MLO u-boot.bin uImage ramdisk.gz boot.scr user.scr ramfs.img"
md5sum $FILES > md5sum.txt

if [ -e ramdisk.gz ]; then
 sd-create-image beagleboard-validation-$DATE.img 16
 sudo losetup -v -o $FS1_OFFSET /dev/loop0 $TMP/beagleboard-validation-$DATE.img
 sudo mkfs.vfat /dev/loop0 -n BEAGLE -F 32 120456
 sudo mount /dev/loop0 /mnt/sd_image1
 sudo cp -R $FILES md5sum.txt /mnt/sd_image1/
 #mount
 #ls -l /mnt/sd_image1/
 #sudo losetup $VFAT_LOOP
 sudo umount /dev/loop0
 sudo losetup -d /dev/loop0
 gzip -c $TMP/beagleboard-validation-$DATE.img > beagleboard-validation-$DATE.img.gz
 mv $TMP/beagleboard-validation-$DATE.img .
fi
 
md5sum demo-$DATE.tar.bz2 >> md5sum.txt
 
if [ -e demo-$DATE.tar.bz2 ]; then
 sd-create-image beagleboard-demo-$DATE.img 444
 sudo losetup -v -o $FS1_OFFSET /dev/loop0 $TMP/beagleboard-demo-$DATE.img
 sudo mkfs.vfat /dev/loop0 -n BEAGLE -F 32 120456
 sudo mount /dev/loop0 /mnt/sd_image1
 sudo cp -R $FILES md5sum.txt /mnt/sd_image1/
 mount
 ls -l /mnt/sd_image1
 sudo losetup /dev/loop0
 sudo umount /dev/loop0
 sudo losetup -d /dev/loop0
 sudo losetup -v -o $FS2_OFFSET /dev/loop0 $TMP/beagleboard-demo-$DATE.img
 sudo mkfs.ext3 -j -L "ANGSTROM" /dev/loop0 3445942
 sudo mount /dev/loop0 /mnt/sd_image2
 sudo tar xjf demo-$DATE.tar.bz2 -C /mnt/sd_image2/
 mount
 sudo losetup /dev/loop0
 sudo umount /dev/loop0
 sudo losetup -d /dev/loop0
 gzip -c $TMP/beagleboard-demo-$DATE.img > beagleboard-demo-$DATE.img.gz
 mv $TMP/beagleboard-demo-$DATE.img .
fi
 
popd
}

# about 50-70 minutes
function rsync-deploy {
mkdir -p $S3_DEPLOY_DIR
cp /mnt/s3/scripts/list.html $S3_DEPLOY_DIR
mkdir -p $S3_DEPLOY_DIR/glibc
cp /mnt/s3/scripts/list.html $S3_DEPLOY_DIR/glibc
rsync -a $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/deploy/glibc $S3_DEPLOY_DIR
}

function rsync-pstage-to-s3 {
mkdir -p /mnt/s3/pstage
cp /mnt/s3/scripts/list.html /mnt/s3/pstage/
# The quilt-native pstage package is bad
rm $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/pstage/*/*quilt-native*
# TI components may have non-free licenses
#rm $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/pstage/*/*ti-*
rsync -a $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/pstage/ /mnt/s3/pstage/
}

function rsync-pstage-from-s3 {
mkdir -p $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/pstage/
rsync -a /mnt/s3/pstage/ $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/pstage/
# The quilt-native pstage package is bad
rm $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/pstage/*/*quilt-native*
# TI components may have non-free licenses
#rm $HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/pstage/*/*ti-*
}

function copy-ti-tools {
find-instance
remote mkdir -p angstrom-setup-scripts/sources/downloads
scp -i $KEYPAIR_FILE $HOME/ti-tools/ti_cgt_c6000_6.1.9_setup_linux_x86.bin ubuntu@$MACH_NAME:angstrom-setup-scripts/sources/downloads/ti_cgt_c6000_6.1.9_setup_linux_x86.bin
}

function setup-oe {
if [ ! -x $HOME/angstrom-setup-scripts/oebb.sh ]; then install-oe; fi
pushd $HOME/angstrom-setup-scripts
git checkout $ANGSTROM_SCRIPT_ID
popd
pushd $HOME/angstrom-setup-scripts/sources/openembedded
git remote add myrepo git://gitorious.org/~Jadon/angstrom/jadon-openembedded.git
git remote update
git checkout $ANGSTROM_REPO_ID
popd
# I could never get the EBS volumes to mount in testing
#remote restore-angstrom
#remote mount-download-ebs
if [ ! -x /mnt/s3/scripts/ec2build.sh ]; then mount-s3; fi
rsync-downloads-from-s3
rsync-pstage-from-s3
# pstage of quilt-native doesn't work
#oebb bitbake -c clean quilt-native
}

function build-image {
setup-oe
# about 90-120 minutes (<60 with pstage)
oebb bitbake beagleboard-test-image
oebb bitbake beagleboard-demo-image
# about 90 seconds
DEPLOY_DIR=$HOME/angstrom-setup-scripts/build/tmp-angstrom_2008_1/deploy/glibc/images/beagleboard
if [ -e $DEPLOY_DIR/beagleboard-test-image-beagleboard.ext2.gz ]; then build-sd; fi
# only about 5 minutes if there aren't many updates
#rsync-downloads-to-s3
#rsync-pstage-to-s3
#rsync-deploy
}

time $*

