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
cd $DIR/x-load
git remote update
git push origin omapzoom/master
git push origin sakoman/master

#
# u-boot
#
cd $DIR/u-boot
git remote update
git push origin upstream/master
git push origin upstream-ti/master
git push origin sakoman/master
git push origin omapzoom/master
git push origin origin/omap3-dev-usb

#
# Linux
#
cd $DIR/linux-2.6
git remote update
git push origin upstream/master
git push origin linux-omap/master
git push origin linux-omap-pm/master
git push origin psp/master
git push origin psp-video/master
git push origin koen/master
git push origin koen/beagleboardXM
git push origin origin/master

