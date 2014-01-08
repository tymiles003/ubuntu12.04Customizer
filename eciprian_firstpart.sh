#!/bin/bash
#@Author: eciprian Matr.N 10154
#This script use dialogs to personalize your Ubuntu 12.04 iso installation.

#SETTINGS########################################################################
wdth=60 #default dialog width and height
hght=20

status=/tmp/status #filepath for keeping score of script current status
tmp=/tmp/answ #filepath for processing selections of the user
Dest=$HOME/liveubuntu #directory path for directing exctracted iso
DESTMP=/tmp/liveubuntu/ #directory path for temporary mounting
isopath_save=/tmp/isopath_save

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

#Delete all unecessary files and unmount when script is ended properly

function clean() {
rm -f $tmp
rm -f $status
rm -f $isopath_save

#To implement next TODO
: <<'END'
if $mountext_Check
 then 
  sudo umount "$DESTMP"
  sudo umount "$Dest/squashfs/"
fi

if $changeroot_Check
 then
  export HOME=$Homeold 
  umount /proc/
  umount /sys/
  exit
fi
echo "Before exit files in $Dest, if present, will be deleted... Confirm? (y/n)\n"
 read Answ
   if test "$Answ" = "y"
     then
       sudo rm -rf $Dest
   fi
END

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
dialog --title 'Welcome' --msgbox 'Hello! This script will allow you to personalize your Ubuntu 12.04 iso installation.\nPlease remember that this is a student work and uses root functionalities. The author does not take any responsability on unexpected behaviours!\n\n\nCheers and press ENTER to continue' $hght $wdth

phases_Check=$( gawk '{ print $1 }' $status ) #load completed phases
[ -f $isopath_save ] && isopath=$( < $isopath_save ) #load iso path if present in file

  if test -n "$phases_Check"
    then 
      for phaseDone in $phases_Check
           do
           start=$phaseDone
           varname=$( echo "${phaseDone}"_Check )
           eval "$varname=true" #dinamically assign true state to correct boolean flag variable
 	done 
      eval "$varname=false" #last phase on file is not actually completed
      dialog --title 'Resume' --yesno 'Apparently, this script was already executed before. Would you like to resume execution?\nYes to continue execution\nNo to restart script\n' $hght $wdth
      if [ $? -eq 0 ]
        then 
          $start #branch to last undone phase
       fi
      clean
      welcome  
  fi
}

#Get original iso:
#2.Select the iso with a fileselect
function getiso() {
getiso_Check=false

dialog --clear --backtitle 'SELECT ISO' --msgbox 'First of all, you need a 12.04 Ubuntu iso.\nSelect an Ubuntu 12.04 iso file' $hght $wdth 2> $tmp
case $? in
       0) isopath=$HOME/Scaricati/ubuntu-12.04.3-desktop-amd64.iso #default possible iso path
          dialog --backtitle 'SELECT ISO' --fselect $isopath  14 48  2> $tmp
              if [ ! $? -eq 0 ]
                 then quit 'getiso'
              fi 
          isopath=$(< $tmp)
          ;;
       1|255) quit 'getiso'
          ;;
   esac

getiso_Check=true
}

#Checks for iso
function checkiso() {
   if ! [ -r $isopath ]
      then dialog --title "Error" --msgbox "$isopath\n\nis not a valid file or you don't have reading ownerships." $hght $wdth
         getiso             
    fi

    printf "$isopath" | grep -q '[.]*\.iso$'
    if ! [ $? -eq 0 ]
       then dialog --title "Error" --msgbox "$isopath\n\nis not an iso file." $hght $wdth
          getiso  
     fi
}             

#Mount and extract iso
function mountext() {
mountext_Check=false
checkiso

dialog --backtitle 'SETUP THE ENVIRONMENT' --title 'Mount Iso' --yesno "Now this script is going to mount the iso in:\n$DESTMP\nand extract the required folders in:\n$Dest\nOriginal iso is:\n$isopath\n\nStart now?" $hght $wdth
case $? in
       0)   echo "Creating necessary directories.."
            [ ! -d $Dest ] && mkdir -p "$Dest" && mkdir -p "$Dest/cd" && mkdir -p "$Dest/squashfs"
            [ ! -d $Dest/custom ] && mkdir -p "$Dest/custom"
            [ ! -d $DESTMP ] && mkdir -p "$DESTMP"
            echo "Mounting iso.."
            sudo mount -o loop "$isopath" "$DESTMP"
            echo "Copying extracted iso.."
            rsync --exclude=/casper/filesystem.squashfs -a $DESTMP $Dest/cd
            echo "Mounting filesystem in $Dest/squashfs.."
            sudo modprobe squashfs
            sudo mount -t squashfs -o loop $DESTMP/casper/filesystem.squashfs $Dest/squashfs/
            echo "Extracting filesystem...please wait 3 minutes."
            sudo cp -a $Dest/squashfs/* $Dest/custom
            sudo cp /etc/resolv.conf $Dest/custom/etc
            sudo cp /etc/hosts $Dest/custom/etc
            echo "DONE"   
          ;;
       1|255) quit 'mountext'
          ;;
esac
mountext_Check=true
}

#Ask for confirmation and warns about changing root,
#If yes change root
#Else exit
function changeroot() {
changeroot_Check=false
dialog --backtitle 'SETUP THE ENVIRONMENT' --title "Change Root" --yesno "Iso successfully extracted!\nNow the the root will be changed to\n$Dest/custom.\nAll the commands that will be executed from now on will be executed inside this folder.\n\nContinue?" $hght $wdth
case $? in
       0) Homeold=$HOME
          sudo chroot $Dest/custom
	  mount -t proc none /proc/
	  mount -t sysfs none /sys/ 
          export HOME=/root     
          ;;
       1|255) quit 'changeroot'
          ;;
esac
changeroot_Check=true
}


#SCRIPT########################################################################
#Program flow executing above procedures (TODO implement check stages/sum up during execution)

instdep 'dialog'
instdep 'squashfs-tools'

welcome
echo "getiso " >> $status
getiso
echo $isopath > $isopath_save
echo "mountext" >> $status
mountext
echo "changeroot" >> $status
changeroot 
quit 'getiso'

exit 0
