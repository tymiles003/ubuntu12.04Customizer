#!/bin/bash
#@Author: eciprian Matr.N 10154
#This script use dialogs to personalize your Ubuntu 12.04 iso installation.

#SETTINGS########################################################################
wdth=60 #default dialog width and height
hght=20
tmp=/tmp/answ #filepath for processing answers
UbuntuUrl64=http://releases.ubuntu.com/precise/ubuntu-12.04.3-desktop-amd64.iso #download link
UbuntuUrl32=http://releases.ubuntu.com/precise/ubuntu-12.04.3-desktop-i386.iso
Md564=e2da0d5ac2ab8bedaa246869e30deb71 #Md5 string for 64bit iso (http://releases.ubuntu.com/precise/MD5SUMS)
Md532=c4f4c7a0d03945b78e23d3aa4ce127dc #Md5 string for 32bit iso
Dest=$HOME/liveubuntu #directory path for directing exctracted iso
DESTMP=/tmp/liveubuntu/ #directory path for temporary mounting
mountext_Check=false

#FUNCTIONS########################################################################

#Checks if the user system has the required package, if not, ask to install it
function instdep() {
depend_Check=false
dpkg --get-selections | grep -q $1
if ! test $? -eq 0
 then
   echo "You need the '$1' package in order to execute this script. Install it now? (y\n)"
   read Answ
   if test "$Answ" = "y"
     then
       sudo apt-get install $1 
   else 
     echo "This script can not continue execution without '$1'. Exit now\n"
     exit -1
   fi
fi
depend_Check=true
}

#Delete all unecessary files and unmount when script is ended at any stage
function clean() {
rm -f $tmp

if $mountext_Check
then 
  sudo umount "$DESTMP"
  sudo umount "$Dest/squashfs/"
fi

}

#Exit functions
#Exit if 'yes' is selected
#Redirect to stated parameter if 'no' is selcted
function quit() {
         dialog --backtitle 'EXIT' --title 'Are you sure, Dude?' --yesno 'Exit now?' $hght $wdth
          case $? in
              0) clean
                 exit 0   
              ;;
              1|255) $1
              ;;
          esac
}

#Get original iso:
#1.Download 32 bit iso
#2 Select the iso with a fileselect
function getiso() {
getiso_Check=false
dialog --clear --backtitle 'SELECT ISO' --menu 'First of all, you need a 12.04 Ubuntu iso.\nSelect one from your disk or download it from the official site.' $hght $wdth 3 1 'Download Ubuntu 12.04 32bit' 2 'Download Ubuntu 12.04 64bit' 3 'Select an Ubuntu 12.04 iso file' 2> $tmp
Answ=$(<$tmp)
succDwn=false

case $Answ in
       1) wget "$UbuntuUrl32" 2> log #(TODO show progress )
          if ! test $? -eq 0
            then dialog --aspect 7 --title "Error" --msgbox "Could not download iso.\n$( cat log )" 0 0
           rm -f log
          getiso
          fi 
          succDwn=true
          isopath=/ubuntu-12.04.3-desktop-i386.iso
          ;;
       2) wget "$UbuntuUrl64" 2> log
          if ! test $? -eq 0
            then dialog --aspect 7 --title "Error" --msgbox "Could not download iso.\n$( cat log )" 0 0
           rm -f log
          getiso
          fi 
          succDwn=true
          isopath=/ubuntu-12.04.3-desktop-amd64.iso
          ;;
       3) isopath=$HOME/Scaricati/ubuntu-12.04.3-desktop-amd64.iso
          dialog --backtitle 'SELECT ISO' --fselect $isopath  14 48  2> $tmp
          isopath=$(<temp) 
          ;;
       *) quit 'getiso'
          ;;
   esac

getiso_Check=true
}

#Checks md5 for downloaded iso
function checkiso() {
         if $succDwn
           then
              echo "Please wait a few seconds while checking iso md5..."
              md5= $(md5sum $isopath)
              if test "$md5" -eq "$Md564" || test "$md5" -eq "$Md532"
                 then dialog --title "Error" --msgbox "Iso Checksum is incorrect. Please be sure the file was correctly downloaded" $hght $wdth
                 getiso            
              fi 
          fi
}

#Mount and extract iso
function mountext() {
mountext_Check=false
dialog --backtitle 'SETUP THE ENVIRONMENT' --title 'Mount Iso' --yesno "Now this script is going to mount the iso in:\n$DESTMP\nand extract the required folders in:\n$Dest\n\nStart now?" $hght $wdth
case $? in
       0)   echo "Creating necessary directories.."
            [ ! -d $Dest ] && mkdir -p "$Dest" && mkdir -p "$Dest/cd" && mkdir -p "$Dest/squashfs"
            [ ! -d $Dest/custom ] && mkdir -p "$Dest/custom"
            [ ! -d $DESTMP ] && mkdir -p "$DESTMP"
            echo "Mounting iso.."
            sudo mount -o loop "$isopath" "$DESTMP"
            echo "Copying extracted iso.."
            rsync --exclude=/casper/filesystem.squashfs -a $DESTMP $Dest
            echo "Mounting filesystem in $Dest/squashfs.."
            sudo modprobe squashfs
            sudo mount -t squashfs -o loop $DESTMP/casper/filesystem.squashfs $Dest/squashfs/
            echo "Extracting filesystem...please wait."
            sudo cp -a $Dest/squashfs/* $Dest/custom
            echo "DONE"    
          ;;
       1|255) quit 'mountext'
          ;;
esac
mountext_Check=true
}

function changeroot() {
 dialog --backtitle 'SETUP THE ENVIRONMENT' --title "Change Root" --yesno "Iso successfully extracted!\nNow the the root will be changed to\n$Dest/custom\n\nContinue?  " $hght $wdth
case $? in
       0)      
          ;;
       1|255) quit 'changeroot'
          ;;
esac
}


#SCRIPT########################################################################
#Program flow executing above procedures (TODO implement check stages/sum up during execution)

instdep 'dialog'
instdep 'squashfs-tools'

#Welcome message 
dialog --title 'Welcome' --msgbox 'Hello! This script will allow you to personalize your Ubuntu 12.04 iso installation.\nPlease remember that this is a student work and uses root functionalities. The author does not take any responsability on unexpected behaviours!\n\n\nCheers and press ENTER to continue' $hght $wdth

getiso
checkiso
mountext
changeroot 

exit 0
