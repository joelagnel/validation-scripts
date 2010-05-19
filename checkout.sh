#!/bin/sh
DIR=`dirname "$0"`/..
ORIGIN=git@gitorious.org:beagleboard-validation
#ORIGIN=git://gitorious.org/beagleboard-validation
OMAPZOOM=git://git.omapzoom.org/repo
DENX=git://git.denx.de
KERNEL=git://git.kernel.org/pub/scm/linux/kernel/git
PSP=git://arago-project.org/git/people
PSP2=git://arago-project.org/git/projects
ROWBOAT=git://gitorious.org/rowboat

#
# x-load
#
mkdir -p $DIR/x-load
cd $DIR/x-load
git init
git remote add origin $ORIGIN/x-load.git
# Steve Sakoman performs public maintainership of x-load for BeagleBoard and Gumstix Overo
git remote add sakoman git://gitorious.org/x-load-omap3/mainline.git
# X-load for the OMAP Zoom/Blaze mobile development platforms from TI
git remote add omapzoom $OMAPZOOM/x-loader.git
# X-load for the OMAP35x EVM, AM3517 EVM, and AM/DM37x plaforms from TI
git remote add psp $PSP2/x-load-omap3.git
git remote update
git checkout -b omapzoom/master --track omapzoom/master
git checkout -b sakoman/master --track sakoman/master
git checkout -b psp/master --track psp/master
git checkout -b master --track origin/master

#
# u-boot
#
mkdir -p $DIR/u-boot
cd $DIR/u-boot
git init
git remote add origin $ORIGIN/u-boot.git
# This is the u-boot mainline where everything should be headed
git remote add upstream $DENX/u-boot.git
# This is where TI stages changes for upstream
git remote add upstream-ti $DENX/u-boot-ti.git
# Steve Sakoman performs public maintainership of u-boot for BeagleBoard and Gumstix Overo
git remote add sakoman git://gitorious.org/u-boot-omap3/mainline.git
# U-boot for the OMAP Zoom/Blaze mobile development platforms from TI
git remote add omapzoom $OMAPZOOM/u-boot.git
# U-boot for the OMAP35x EVM, AM3517 EVM, and AM/DM37x plaforms from TI
git remote add psp $PSP2/u-boot-omap3.git
git remote update
git checkout -b upstream/master --track upstream/master
git checkout -b upstream-ti/master --track upstream-ti/master
git checkout -b sakoman/master --track sakoman/master
git checkout -b omapzoom/master --track omapzoom/master
git checkout -b psp/master --track psp/master
git checkout -b omap3-dev-usb --track origin/omap3-dev-usb
git checkout -b master --track origin/master

#
# Linux
#
mkdir -p $DIR/linux-2.6
cd $DIR/linux-2.6
git init
git remote add origin $ORIGIN/linux.git
# This is Linux
git remote add upstream $KERNEL/torvalds/linux-2.6.git
# This is where patches are staged for Linus
git remote add linux-omap $KERNEL/tmlind/linux-omap-2.6.git
# This is a working tree for power management code
git remote add linux-omap-pm $KERNEL/khilman/linux-omap-pm.git
# Linux for the OMAP35x EVM, AM3517 EVM, and AM/DM37x plaforms from TI
git remote add psp $PSP/sriram/ti-psp-omap.git
# Work on-going to improve the V4L support
git remote add psp-video $PSP/vaibhav/ti-psp-omap-video.git
# Koen's kernel for the Angstrom distribution
git remote add koen git://gitorious.org/angstrom/angstrom-linux.git
# A kernel patched to support Android as part of the ARowboat.org project
git remote add rowboat $ROWBOAT/kernel.git
git remote update
git checkout -b upstream/master --track upstream/master
git checkout -b linux-omap/master --track linux-omap/master
git checkout -b linux-omap-pm/master --track linux-omap-pm/master
git checkout -b psp/master --track psp/master
git checkout -b psp-video/master --track psp-video/master
git checkout -b koen/master --track koen/master
git checkout -b koen/beagleboardXM --track koen/beagleboardXM
git checkout -b master --track origin/master
git checkout -b rowboat/master --track rowboat/master

