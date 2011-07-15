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
set -x
set -e

#FIXME: Have the script auto set this up and by look at its patch
SCRIPTS_DIR=/home/joel/repo/validation-scripts/
DOWNLOAD_DIR=/home/joel/repo/validation-scripts/downloads/

if [ ! -e ~/.oebuild.env ]; then
  echo "Please setup an ~/.oebuild.env that has location of setup scripts (OEBB_DIR)";
  exit
fi
source ~/.oebuild.env

# These are the git commit ids we want to use to build
ANGSTROM_SCRIPT_ID=c714eecb0ed532f70cde435c05e420809d59a534
ANGSTROM_REPO_ID=a1f31c757d2514e946737d60789c6f9f05ce38eb

DATE=`date +%Y%m%d%H%M`
THIS_FILE=$0

function remote {
run-ami
ssh -i $KEYPAIR_FILE ubuntu@$MACH_NAME 'mkdir -p $HOME/secret; chmod 700 $HOME/secret'
scp -i $KEYPAIR_FILE $EC2_CERT ubuntu@$MACH_NAME:secret/cert.pem
scp -i $KEYPAIR_FILE $EC2_PRIVATE_KEY ubuntu@$MACH_NAME:secret/pk.pem
scp -i $KEYPAIR_FILE $HOME/secret/setup_env.sh ubuntu@$MACH_NAME:secret/setup_env.sh
ssh-ami mkdir -p $SCRIPT_DIR
scp -i $KEYPAIR_FILE $THIS_FILE ubuntu@$MACH_NAME:$SCRIPT_DIR/ec2build.sh
scp -i $KEYPAIR_FILE $THIS_FILE ubuntu@$MACH_NAME:$SCRIPT_DIR/set-threads.pl
ssh-ami $SCRIPT_DIR/ec2build.sh $1 $2 $3 $4 $5 $6 $7 $8
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
 desktop-file-utils chrpath \
 libxml2-utils xmlto python-psyco \
 python-xcbgen \
 ia32-libs \
 m4 \
 gnome-doc-utils \
 libtool \
 patch libexpat-dev libbonobo2-common libncurses5-dev \
 -y
}

# target local
# about 5 minutes
function install-oe {
	#export THREADS=`$SCRIPT_DIR/set-threads.pl`
	#mkdir -p $OEBB_DIR
	#sudo mount -t ramfs -o size=10G ramfs $OEBB_DIR
	rm -rf $HOME/.oe || true
	rm -rf $OEBB_DIR
	mkdir -p $OEBB_DIR
	git clone git://git.angstrom-distribution.org/setup-scripts $OEBB_DIR
	cd $OEBB_DIR
	git checkout $ANGSTROM_SCRIPT_ID
	git checkout -b install || true
	./oebb.sh config beagleboard
	./oebb.sh update
	perl -pe 's/^(INHERIT\s*\+=\s*"rm_work")/#$1/' -i.bak1 $OEBB_DIR/build/conf/local.conf
	perl -pe 's/^(#)?PARALLEL_MAKE\s*=\s*"-j\d+"/PARALLEL_MAKE = "-j8"/' -i.bak2 $OEBB_DIR/build/conf/local.conf
	perl -pe 's/BB_NUMBER_THREADS\s*=\s*"\d+"/BB_NUMBER_THREADS = "10"/' -i.bak3 $OEBB_DIR/build/conf/local.conf
}

# target local
function oebb {
	cd $OEBB_DIR
	./oebb.sh $1 $2 $3 $4 $5 $6 $7 $8 $9
}

function preserve-angstrom {
	rsync -a $OEBB_DIR/* /mnt/angstrom/
}

# target local
# takes about 16 minutes
function bundle-vol {
	IMAGE_NAME=beagleboard-validation-$DATE
	echo IMAGE_NAME=$IMAGE_NAME
	sudo mkdir -p $DOWNLOAD_DIR
	sudo chown ubuntu.ubuntu $DOWNLOAD_DIR
	sudo mkdir -p $OEBB_DIR
	sudo chown ubuntu.ubuntu $OEBB_DIR
	sudo mv /mnt/$IMAGE_NAME $IMAGE_NAME.$$ || true
	sudo ec2-bundle-vol -c $EC2_CERT -k $EC2_PRIVATE_KEY -u $EC2_ID -r x86_64 -d /mnt -e /mnt,/home/ubuntu/secret,$DOWNLOAD_DIR,$OEBB_DIR -p $IMAGE_NAME
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
sudo umount /dev/loop0 || true
sudo losetup -d /dev/loop0 || true
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
IMAGE=$1
[ -z "$2" ] || DATE=$2

if [ ! -x /mnt/s3/scripts/ec2build.sh ]; then mount-s3; fi
S3_DEPLOY_DIR=/mnt/s3/deploy/$DATE
mkdir -p $S3_DEPLOY_DIR/sd/
sudo mkdir -p /mnt/sd_image1
sudo mkdir -p /mnt/sd_image2
pushd $S3_DEPLOY_DIR/sd/
DEPLOY_DIR=$OEBB_DIR/build/tmp-angstrom_2008_1/deploy/glibc/images/beagleboard
cp /mnt/s3/scripts/list.html .
cp $DEPLOY_DIR/MLO-beagleboard MLO
cp $DEPLOY_DIR/u-boot-beagleboard.bin u-boot.bin
cp $DEPLOY_DIR/uImage-beagleboard.bin uImage
cp $DEPLOY_DIR/beagleboard-test-image-beagleboard.ext2.gz ramdisk.gz
#cp $DEPLOY_DIR/beagleboard-test-image-beagleboard.cpio.gz.u-boot ramfs.img
cp $DEPLOY_DIR/uboot-beagleboard-validation-user.cmd.scr user.scr
cp $SCRIPT_DIR/ec2build.sh .
echo "$DATE  DATE" > md5sum.txt
echo "$ANGSTROM_SCRIPT_ID  ANGSTROM_SCRIPT_ID" > md5sum.txt
echo "$ANGSTROM_REPO_ID  ANGSTROM_REPO_ID" >> md5sum.txt
FILES="MLO u-boot.bin uImage ramdisk.gz user.scr"
md5sum $FILES >> md5sum.txt

if [ "x$IMAGE" = "xtest" ]; then
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
fi
 
if [ "x$IMAGE" = "xdemo" ]; then
 cp $DEPLOY_DIR/uboot-beagleboard-validation-boot.cmd.scr boot.scr
 cp $DEPLOY_DIR/Beagleboard-demo-image-beagleboard.tar.bz2 demo-$DATE.tar.bz2
 md5sum boot.scr demo-$DATE.tar.bz2 >> md5sum.txt
 
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
  pushd /mnt/sd_image2/
  sudo perl -00pe "s/\[daemon\]\n\n/[daemon]\nTimedLoginEnable=true\nTimedLogin=root\nTimedLoginDelay=10\n\n/" -i.bak etc/gdm/custom.conf
  #sudo sh -c 'echo "boris:x:1000:1000:Boris the Beagle:/home/boris:/bin/sh" >> etc/passwd'
  #sudo sh -c 'echo "boris:!:14841:0:99999:7:::" >> etc/shadow'
  #sudo mkdir -p home/boris
  #sudo chown 1000.1000 home/boris
  sudo mkdir -p usr/share/esc-training
  pushd usr/share/esc-training
  sudo git clone git://git.kernel.org/pub/scm/git/git.git
  sudo git clone git://git.denx.de/u-boot.git
  pushd u-boot
  sudo git remote add beagleboard-validation git://gitorious.org/beagleboard-validation/u-boot.git
  sudo git remote update
  popd
  popd
  sudo tar --no-same-owner --owner=root -xzf $OEBB_DIR/sources/downloads/demohome.tgz
  # opkg update
  # opkg install nodejs linuxtag-ics
  OETMPDIR=$OEBB_DIR/build/tmp-angstrom_2008_1/
  OEBINDIR=$OETMPDIR/sysroots/x86_64-linux/usr/bin
  OEIPKDIR=$OETMPDIR/deploy/glibc/ipk
  OPKGARGS="--cache /mnt/ubuntu-tmp -o /mnt/sd_image2 -f /mnt/sd_image2/etc/opkg/opkg.conf"
  #sudo $OEBINDIR/opkg-cl --cache /mnt/ubuntu-tmp -o /mnt/sd_image2 -f /mnt/sd_image2/etc/opkg/opkg.conf update
  #sudo sh -c "yes | $OEBINDIR/opkg-cl $OPKGARGS install nodejs"
  #sudo sh -c "yes | $OEBINDIR/opkg-cl $OPKGARGS install linuxtag-ics"
  #sudo sh -c "yes | $OEBINDIR/opkg-cl $OPKGARGS install qmake2"
  popd
  mount
  sudo losetup /dev/loop0
  sudo umount /dev/loop0
  sudo losetup -d /dev/loop0
  gzip -c $TMP/beagleboard-demo-$DATE.img > beagleboard-demo-$DATE.img.gz
  mv $TMP/beagleboard-demo-$DATE.img .
  wget -O - http://beagleboard-validation.s3.amazonaws.com/deploy/$DATE/sd/beagleboard-demo-$DATE.img.gz?torrent > beagleboard-demo-$DATE.img.gz.torrent
 fi
fi
 
popd
}

function build_package {
	pushd $OEBB_DIR
	MACHINE=beagleboard ./oebb.sh bitbake $1
	popd
}
 
function apply_oe_downloads {
	mkdir -p $OEBB_DIR/sources/downloads/
	cp $DOWNLOAD_DIR/bin/* $OEBB_DIR/sources/downloads/
	pushd $OEBB_DIR/sources/openembedded/
	perl -pe 's/^(SRC_URI\[cgt6xbin.md5sum\] =).*/$1 5ee5c8e573ab0a1ba1249511d4a06c27/' \
			-i recipes/ti/ti-cgt6x_6.1.17.bb
	perl -pe 's/^(SRC_URI\[cgt6xbin.sha256sum\] =).*/$1 0cb99e755f5d06a74db22d7c814e4dfd36aa5fcb35eeab01ddb000aef99c08c1/' \
			-i recipes/ti/ti-cgt6x_6.1.17.bb
	popd
}

function setup_oe {
	if [ ! -x $OEBB_DIR/oebb.sh ]; then install-oe; fi
	pushd $OEBB_DIR
	git checkout $ANGSTROM_SCRIPT_ID
	if [ ! -d sources/openembedded/.git ]; then
	 ./oebb.sh update
	fi
	pushd sources/openembedded
	git checkout $ANGSTROM_REPO_ID
	popd
	popd
}

function build_image {
	setup_oe
	apply_oe_downloads
	build_package beagleboard-validation-gnome-image
}

time $*

