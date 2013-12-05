#!/bin/bash
#@Author: eciprian Matr.N 10154
#This script use dialogs to personalize your Ubuntu 12.04 iso installation.

#SETTINGS########################################################################
wdth=60 #default dialog width and height
hght=20
status=/tmp/status #filepath for keeping score of script current status(TODO implement resume if ended with ctrl-z)
tmp=/tmp/answ #filepath for processing selections of the user
UbuntuUrl64=http://releases.ubuntu.com/precise/ubuntu-12.04.3-desktop-amd64.iso #download link
UbuntuUrl32=http://releases.ubuntu.com/precise/ubuntu-12.04.3-desktop-i386.iso
Md564=e2da0d5ac2ab8bedaa246869e30deb71 #Md5 string for 64bit iso (http://releases.ubuntu.com/precise/MD5SUMS)
Md532=c4f4c7a0d03945b78e23d3aa4ce127dc #Md5 string for 32bit iso
Dest=$HOME/liveubuntu #directory path for directing exctracted iso
DESTMP=/tmp/liveubuntu/ #directory path for temporary mounting

depend_Check=false
getiso_Check=false
mountext_Check=false
changeroot_Check=false


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

#Delete all unecessary files and unmount when script is ended and exit
function clean() {
rm -f $tmp
rm -f $status

if $mountext_Check
 then 
  sudo umount "$DESTMP"
  sudo umount "$Dest/squashfs/"
fi

if $changeroot_Check
 then
  umount /proc/
  umount /sys/
  exit
  sudo rm -rf $Dest
  
fi 
exit 0 
} 

#Exit function
#Exit if 'yes' is selected
#Redirect to stated parameter if 'no' is selected
function quit() {
         dialog --backtitle 'EXIT' --title 'Are you sure, Dude?' --yesno 'Exit now?' $hght $wdth
          case $? in
              0) exit 0   
              ;;
              1|255) $1
              ;;
          esac
}

#Welcome or resume execution according to status file
function welcome() {
[ ! -f $status ] && touch $status
dialog --title 'Welcome' --msgbox 'Hello! This script will allow you to personalize your Ubuntu 12.04 iso installation.\nPlease remember 		that this is a student work and uses root functionalities. The author does not take any responsability on unexpected behaviours!\n\n\nCheers 		and press ENTER to continue' $hght $wdth

phases_Check=$( gawk '{ print $1 }' $status )
echo "$phases_Check"
  if test -n "$phases_Check"
    then  
      dialog --title 'Resume' --yesno 'Apparently, this script was already executed before. Would you like to resume execution?\nYes to continue execution\nNo to restart script\n' $hght $wdth
      if [ $? -eq 0 ]
        then 
  	for phaseDone in $phases_Check
           do
           start=$phaseDone
           "$phaseDone"_Check=true
 	done
        $start
      else
       rm -f $status
     fi  
  fi
}

#Get original iso:
#1.Download 32 bit iso
#2.Select the iso with a fileselect
function getiso() {
getiso_Check=false

dialog --clear --backtitle 'SELECT ISO' --menu 'First of all, you need a 12.04 Ubuntu iso.\nSelect one from your disk or download it from the official site.' $hght $wdth 3 1 'Download Ubuntu 12.04 32bit' 2 'Download Ubuntu 12.04 64bit' 3 'Select an Ubuntu 12.04 iso file' 2> $tmp
Answ=$(<$tmp)
succDwn=false

case $Answ in
       1) wget --debug --tries 1 "$UbuntuUrl32"
          if ! test $? -eq 0
            then dialog --aspect 7 --title "Error" --msgbox "Downloding the iso reported an error.\nPlease check your internet connection." 0 0
                 rm -f /ubuntu-12.04.3-desktop-i386.iso
                 getiso
          fi 
          succDwn=true
          isopath=/ubuntu-12.04.3-desktop-i386.iso
          ;;
       2) wget --debug --tries 1 "$UbuntuUrl64"
          if ! test $? -eq 0
            then dialog --aspect 7 --title "Error" --msgbox "Downloding the iso reported an error.\nPlease check your internet connection." 0 0
    		 rm -f /ubuntu-12.04.3-desktop-amd64.iso	      
                 getiso
          fi 
          succDwn=true
          isopath=/ubuntu-12.04.3-desktop-amd64.iso
          ;;
       3) isopath=$HOME/Scaricati/ubuntu-12.04.3-desktop-amd64.iso
          dialog --backtitle 'SELECT ISO' --fselect $isopath  14 48  2> $tmp
              if [ ! $? -eq 0 ]
                 then quit 'getiso'
              fi 
          isopath=$(< $tmp)
          ;;
       *|0) quit 'getiso'
          ;;
   esac

getiso_Check=true
echo "getiso OK" >> $status
}

#Checks md5 for iso
function checkiso() {
         if $succDwn
           then
              echo "Please wait a few seconds while checking iso md5..."
              md5= $(md5sum $isopath)
              if test "$md5" -eq "$Md564" || test "$md5" -eq "$Md532"
                 then dialog --title "Error" --msgbox "Iso Checksum is incorrect. Please be sure the file was correctly downloaded" $hght $wdth
                 getiso 
              fi 
          else 
              if ! [ -r $isopath ]
                 then dialog --title "Error" --msgbox "$isopath\n\nis not a valid file or you don't have reading ownerships." $hght $wdth
                 getiso             
              fi
              grep -q '[.]*\.iso$' $tmp 
              if ! [ $? -eq 0 ]
                 then dialog --title "Error" --msgbox "$isopath\n\nis not an iso file." $hght $wdth
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
            echo "Extracting filesystem...please wait 3 minutes."
            sudo cp /etc/resolv.conf $Dest/custom/etc
            sudo cp /etc/hosts $Dest/custom/etc
            echo "DONE"    
          ;;
       1|255) quit 'mountext'
          ;;
esac
mountext_Check=true
echo "mountext OK" >> $status
}

#Ask for confirmation and warns about changing root,
#If yes change root
#Else exit
function changeroot() {
changeroot_Check=false
dialog --backtitle 'SETUP THE ENVIRONMENT' --title "Change Root" --yesno "Iso successfully extracted!\nNow the the root will be changed to\n$Dest/custom.\nAll the commands that will be executed from now on will be executed inside this folder.\n\nContinue?  " $hght $wdth
case $? in
       0) sudo chroot $Dest/custom
	  mount -t proc none /proc/
	  mount -t sysfs none /sys/
          export HOME=/root     
          ;;
       1|255) quit 'changeroot'
          ;;
esac
changeroot_Check=true
echo "changeroot OK" >> $status
}


#SCRIPT########################################################################
#Program flow executing above procedures (TODO implement check stages/sum up during execution)

instdep 'dialog'
instdep 'squashfs-tools'

welcome
getiso
checkiso
mountext
changeroot 
quit 'getiso'

exit 0
