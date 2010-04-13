#!/bin/sh
DIR=`dirname "$0"`/..
ORIGIN=git@gitorious.org:beagleboard-validation
#ORIGIN=git://gitorious.org/beagleboard-validation
OMAPZOOM=git://git.omapzoom.org/repo
DENX=git://git.denx.de
KERNEL=git://git.kernel.org/pub/scm/linux/kernel/git
PSP=git://arago-project.org/git/people

#
# x-load
#
mkdir -p $DIR/x-load
cd $DIR/x-load
git init
git remote add origin $ORIGIN/x-load.git
git remote add sakoman git://gitorious.org/x-load-omap3/mainline.git
git remote add omapzoom $OMAPZOOM/x-loader.git
git remote update
git checkout -b omapzoom/master omapzoom/master
git checkout -b sakoman/master sakoman/master
git checkout -b master origin/master

#
# u-boot
#
mkdir -p $DIR/u-boot
cd $DIR/u-boot
git init
git remote add origin $ORIGIN/u-boot.git
git remote add upstream $DENX/u-boot.git
git remote add upstream-ti $DENX/u-boot-ti.git
git remote add sakoman git://gitorious.org/u-boot-omap3/mainline.git
git remote add omapzoom $OMAPZOOM/u-boot.git
git remote update
git checkout -b upstream/master upstream/master
git checkout -b upstream-ti/master upstream-ti/master
git checkout -b sakoman/master sakoman/master
git checkout -b omapzoom/master omapzoom/master
git checkout -b omap3-dev-usb origin/omap3-dev-usb
git checkout -b master origin/master

#
# Linux
#
mkdir -p $DIR/linux-2.6
cd $DIR/linux-2.6
git init
git remote add origin $ORIGIN/linux.git
git remote add upstream $KERNEL/torvalds/linux-2.6.git
git remote add linux-omap $KERNEL/tmlind/linux-omap-2.6.git
git remote add linux-omap-pm $KERNEL/khilman/linux-omap-pm.git
git remote add psp $PSP/sriram/ti-psp-omap.git
git remote add psp-video $PSP/vaibhav/ti-psp-omap-video.git
git remote add koen git://gitorious.org/angstrom/angstrom-linux.git
git remote update
git checkout -b upstream/master upstream/master
git checkout -b linux-omap/master linux-omap/master
git checkout -b linux-omap-pm/master linux-omap-pm/master
git checkout -b psp/master psp/master
git checkout -b psp-video/master psp-video/master
git checkout -b koen/master koen/master
git checkout -b koen/beagleboardXM koen/beagleboardXM
git checkout -b master origin/master

