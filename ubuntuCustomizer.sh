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
allowmultiverse_Check=false
packgmenu_Check=false


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
dialog --title 'Welcome' --msgbox "Hello! This script will allow you to personalize your Ubuntu 12.04 iso installation.\nPlease remember that this is a student work and uses root functionalities.\nPlease make sure you have:\n-a working internet connection\n-at least 3gb of space in ${HOME}\nThe author does not take any responsability on unexpected behaviours!\n\n\nCheers and press ENTER to continue" $hght $wdth

echo "getiso" >> $status
getiso
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
echo $isopath > $isopath_save
echo "mountext" >> $status
mountext
}

#Checks for iso
function checkiso() {
   if ! [ -r "$isopath" ]
      then dialog --title "Error" --msgbox "$isopath\n\nis not a valid file or you don't have reading ownerships." $hght $wdth
         getiso             
    fi

    printf "$isopath" | grep -q '[.]*\.iso$'
    if ! [ $? -eq 0 ]
       then dialog --title "Error" --msgbox "$isopath\n\nis not an iso file." $hght $wdth
          getiso  
     fi
}             

#Checks existence of a liveubuntu folder 
function checkworkspace() {
if [ -e $Dest/custom ] && [ -e $Dest/custom/etc/hosts ]
  then dialog --title "Workspace found!" --yesno "There is already a /liveubuntu folder in your home directory, do you want to keep it and continue working with it?\n" $hght $wdth
       case $? in
                0) echo "changeroot" >> $status
                   mountext_Check=true   
                   changeroot
                   ;;           
		1) if [ mount | grep "$HOME/liveubuntu/squashfs" ]
		      then sudo umount -fld $Dest/squashfs
                   fi
                   ;;
		2|255) quit 'checkworkspace' ;;
	esac

fi 
}

#Mount and extract iso
function mountext() {
mountext_Check=false
checkiso
checkworkspace

if ! $mountext_Check
then
	dialog --backtitle 'SETUP THE ENVIRONMENT' --title 'Mount Iso' --yesno "Now this script is going to mount the iso in:\n$DESTMP\nand extract the required folders in:\n$Dest\nOriginal iso is:\n$isopath\n\nThis process will require at least 3 minutes.\nStart now?" $hght $wdth
	case $? in
       		0)echo "Creating necessary directories.."
            	  [ ! -d $Dest ] && mkdir -p "$Dest" && mkdir -p "$Dest/cd" && mkdir -p "$Dest/squashfs"
            	  [ ! -d $Dest/custom ] && mkdir -p "$Dest/custom"
            	  [ ! -d $DESTMP ] && mkdir -p "$DESTMP"
                  echo "Mounting iso.."
            	  sudo mount -o loop "$isopath" "$DESTMP" > /dev/null
                  echo "Copying extracted iso.."
            	  rsync --exclude=/casper/filesystem.squashfs -a $DESTMP $Dest/cd
            	  echo "Mounting filesystem in $Dest/squashfs.."
             	  sudo modprobe squashfs
                   if [ mount | grep "$HOME/liveubuntu/squashfs" ]
		      then sudo umount -fld $Dest/squashfs
                   fi
            	  sudo mount -t squashfs -o loop $DESTMP/casper/filesystem.squashfs $Dest/squashfs/
            	  echo "Extracting filesystem...please wait 3 minutes."
            	  sudo cp -a $Dest/squashfs/* $Dest/custom
            	  sudo cp /etc/resolv.conf $Dest/custom/etc/
            	  sudo cp /etc/hosts $Dest/custom/etc/
            	  echo "DONE";;
       		1|255) quit 'mountext';;
	esac
fi
mountext_Check=true
echo "changeroot" >> $status
changeroot
}

#Ask for confirmation and warns about changing root,
#If yes change root and mount
#Else exit
function changeroot() {
changeroot_Check=false
dialog --backtitle 'SETUP THE ENVIRONMENT' --title "Change Root" --yesno "Iso successfully extracted!\nNow the the root will be changed to\n$Dest/custom.\nAll the commands that will be executed from now on will be executed inside this folder. Then you will be able to add/remove packages.\n\nContinue?" $hght $wdth
case $? in
       0)        
	  sudo chroot $Dest/custom umount /proc/ > /dev/null
          sudo chroot $Dest/custom umount /sys/ > /dev/null
          sudo chroot $Dest/custom mount -t proc none /proc/ > /dev/null
	  sudo chroot $Dest/custom mount -t sysfs none /sys/ > /dev/null;;
       1|255) quit 'changeroot';;
esac

changeroot_Check=true
echo "allowmultiverse" >> $status
allowmultiverse
}

#Ask to enable multiverse repository by rewriting the sources.list file
function allowmultiverse() {
allowmultiverse_Check=false

dialog --title "Enable Multiverse Repositories" --yesno "Do you want to activate multiverse repositories?\nThis will allow you to install extra packages later." $hght $wdth
case $? in
	0) sudo rm -f $Dest/custom/etc/apt/sources.list		
           echo "deb http://us.archive.ubuntu.com/ubuntu/ precise-backports main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
  	   echo "deb-src http://us.archive.ubuntu.com/ubuntu/ precise-security main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
 	  echo "deb http://us.archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list 
  	  echo "deb-src http://us.archive.ubuntu.com/ubuntu/ precise main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list 
          echo "deb http://us.archive.ubuntu.com/ubuntu/ precise-security main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
          echo "deb http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
          echo "deb http://us.archive.ubuntu.com/ubuntu/ precise-proposed main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
  	  echo "deb-src http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
          echo "deb-src http://us.archive.ubuntu.com/ubuntu/ precise-proposed main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
          echo "deb-src http://us.archive.ubuntu.com/ubuntu/ precise-backports main restricted universe multiverse" | sudo tee -a $Dest/custom/etc/apt/sources.list
          sudo chroot $Dest/custom apt-get update
           ;;
	2|255) quit 'allowmultiverse' ;;
esac

allowmultiverse_Check=true
echo "packgmenu" >> $status
packgmenu
}

function addrepo() {
dialog --backtitle 'CUSTOMIZE' --title 'Add Repositories' --inputbox "Write the Url you want to add"  $hght $wdth 2> $tmp
Url=$(< $tmp)
   if [ awk '/^[http:\/\/]+([*.])+\.[a-z]{2,5}$/' $tmp ]
     then
     sudo chroot $Dest/custom apt-add-repository $Url
		if test $? -ne 0
		then
		   dialog --title 'Error' --msgbox "The Url:\n$Url\nis not valid" $hght $wdth
		else
		   dialog --title 'Add Repositories' --msgbox "Repository Added!" $hght $wdth
                fi
    else
        dialog --title "Error" --msgbox "$Url\nis not valid\nPlease insert a valid url" $hght $wdth
fi
packgmenu
}

#Remove package automatically
function removepckg() {
dialog --backtitle 'CUSTOMIZE' --title "Remove Package automatically" --inputbox "Enter a package name you want to remove." $hght $wdth 2> $tmp
pckg=$(< $tmp)
    if test $? -eq 0
  	   then
              sudo chroot $Dest/custom apt-get purge --assume-yes "$pckg"
       			if test $? -ne 0
  	   		  then        		  
                            dialog --title 'Error' --msgbox "The $pckg package failed removal\n" $hght $wdth                      
       			else
             		    echo "$pckg successfully removed!"
       			fi
    fi
packgmenu 
}

#Allow the user to select among different personalizations.
function packgmenu() {
packgmenu_Check=false
dialog --backtitle 'CUSTOMIZE' --title "Choose an option" --menu "You can use the UP/DOWN arrow keys.\n
Choose a task or end the customization." 30 $wdth 5 \
1 "Add new repositories" \
2 "Add new packages automatically" \
3 "Add a package manually" \
4 "Remove an installed package" \
5 "Change default background" \
6 "End customization" 2> $tmp 

answ=$(< $tmp)
case $answ in
       1) addrepo;;
       2) autoinstll;;
       3) maninstll;;
       4) removepckg;;
       5) ;;
       6|255) quit 'packgmenu';;
       0) quit 'packgmenu';;
esac

packgmenu_Check=true
}


#SCRIPT########################################################################
#Program flow executing above procedures (TODO implement check stages/sum up during execution)

instdep 'dialog'
instdep 'squashfs-tools'

phases_Check=$( gawk '{ print $1 }' $status ) #load completed phases
[ -f $isopath_save ] && isopath=$( < $isopath_save ) #load iso path if present in file

  if test -n "$phases_Check"
    then 
      for phaseDone in $phases_Check
           do
           start=$phaseDone
           varname=$( echo "${phaseDone}"_Check )
           eval "$varname=true" #assign true state to correct boolean flag variable
 	done 
      eval "$varname=false" #last phase on file is not actually completed
      dialog --title 'Resume' --yesno 'Apparently, this script was already executed before. Would you like to resume execution?\nYes to continue execution\nNo to restart script\n' $hght $wdth
      if [ $? -eq 0 ]
        then 
        case $start in  #branch to last undone phase
           welcome) welcome;;
	   getiso) getiso;;
 	   mountext) mountext;;
	   changeroot) changeroot;;
	   allowmultiverse) allowmultiverse;;
           packgmenu) packgmenu;;
	 esac  
       fi
      clean
      welcome		
  fi



exit 0
