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

if $changeroot_Check
 then
 sudo chroot $Dest/custom umount /dev/pts > /dev/null
 sudo chroot $Dest/custom umount /proc/ > /dev/null
 sudo chroot $Dest/custom umount /sys/ > /dev/null
 sudo umount $Dest/custom/dev > /dev/null
fi

#To implement next TODO
: <<'END'
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
         dialog --backtitle 'EXIT' --title 'Are you sure, Dude?' --yesno 'Exit now?\nYou will be able to resume execution from here' $hght $wdth
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
       0) isopath=$HOME/ #default possible iso path
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
		1) mount | grep --silent "$HOME/liveubuntu/squashfs"
                   if [  $? -eq 0 ]
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
                  mount | grep "$HOME/liveubuntu/squashfs"
		   if [  $? -eq 0 ]
		      then sudo umount -fld $Dest/squashfs
                   fi
            	  sudo mount -t squashfs -o loop $DESTMP/casper/filesystem.squashfs $Dest/squashfs/
            	  echo "Extracting filesystem...please wait 3 minutes."
            	  sudo cp -a $Dest/squashfs/* $Dest/custom
            	  sudo cp /etc/resolv.conf $Dest/custom/etc/
            	  sudo cp /etc/hosts $Dest/custom/etc/

		  sudo umount -fld $Dest/squashfs
                  sudo umount $DESTMP
                  sudo rm -fr $DESTMP
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
       0) mount | grep --silent "$Dest/custom/dev"
	   if [ $? -eq 0 ]
             then
          sudo chroot $Dest/custom umount /dev/pts > /dev/null
          sudo chroot $Dest/custom umount /proc/ > /dev/null
          sudo chroot $Dest/custom umount /sys/ > /dev/null
          sudo umount $Dest/custom/dev
           fi
	  
          sudo chroot $Dest/custom mount -t proc none /proc/ > /dev/null
	  sudo chroot $Dest/custom mount -t sysfs none /sys/ > /dev/null
 	  sudo chroot $Dest/custom mount -t devpts none /dev/pts
	  sudo mount --bind /dev/ $Dest/custom/dev;;
       1|255) quit 'changeroot';;
esac

changeroot_Check=true
echo "allowmultiverse" >> $status
allowmultiverse
}

#TODO
: <<'END'
#Check internet connection for next steps 
function checketh() {
pingok=true
  while $pingok
  do
  nmap -sP 192.168.0.0-255
    if ! test $? -eq 0 
       then 
	 dialog --title 'Error' --msgbox "Your internet connection is not working.\nPlease make sure you are connected before proceeding" $hght $wdth       
           if ! test $? -eq 0 
               then 
		quit 'allowmultiverse'
            fi
    else pingok=false
    fi 
  done
  
}
END

#Ask to enable multiverse repository by rewriting the sources.list file
#By default there are no commented repositories in 12.04
function allowmultiverse() {
allowmultiverse_Check=false

dialog --title "Enable Multiverse Repositories" --yesno "Do you want to activate multiverse repositories?\nThis will allow you to install extra packages later.\nMake sure your internet connection is working." $hght $wdth
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

#Check correctness and add the repo
function addrepo() {
dialog --backtitle 'CUSTOMIZE' --title 'Add Repositories' --inputbox "Write the PPA you want to add.\nMake sure your internet connection is working."  $hght $wdth 2> $tmp
Url=$(< $tmp)
     sudo chroot $Dest/custom apt-add-repository --yes $Url		
		if test $? -ne 0
 		  then
		   dialog --title 'Error' --msgbox "The Url:\n$Url\nis not valid" $hght $wdth
		   packgmenu
		else
		   dialog --title 'Add Repository' --msgbox "Repository Added!" $hght $wdth
                   echo "Updating Apt...."
		   sudo chroot $Dest/custom apt-get update > /dev/null 
                fi
packgmenu
}

#Add new package automatically
function autoinstll() {
dialog --backtitle 'CUSTOMIZE' --title "Install Package automatically" --inputbox "Enter a package name.\nMake Sure your internet connection is working and you have added the required PPA, if necessary." $hght $wdth 2> $tmp
pckg=$(< $tmp)
    if test $? -eq 0
  	   then
              sudo chroot $Dest/custom apt-get install --assume-yes "$pckg"
       			if test $? -ne 0
  	   		  then        		  
                            dialog --title 'Error' --msgbox "The $pckg package failed installation\n" $hght $wdth
			    packgmenu                      
       			else
             		    dialog --title 'Done' --infobox "$pckg successfully installed!" $hght $wdth; sleep 3
       			fi
    fi
packgmenu 
}

#Select a .deb file and install it wih dependecies
function maninstll() {
dialog --backtitle 'CUSTOMIZE' --title "Select the .deb file" --fselect $HOME/Scaricati 14 48 2> $tmp
pckg=$(< $tmp)
printf "$pckg" | grep --silent '[.]*\.deb$'
    if test $? -eq 0
  	   then
	      cp $pckg $Dest/custom/tmp
              sudo chroot $Dest/custom dpkg -i tmp/$(basename "$pckg")
	      sudo chroot $Dest/custom apt-get install -f --assume-yes
       			if test $? -ne 0
  	   		  then        		  
                            dialog --title 'Error' --msgbox "The $pckg package failed installation\n" $hght $wdth
	                    packgmenu                      
       			else
			    dialog --title 'Done' --infobox "$pckg successfully installed!\n" $hght $wdth; sleep 3	            
       			fi
    else 
	 dialog --title 'Error' --msgbox "$pckg is not a valid .deb file" $hght $wdth
    fi
sudo rm -f $Dest/custom/tmp/$(basename "$pckg")
packgmenu 
}

#Remove package automatically
function removepckg() {
dialog --backtitle 'CUSTOMIZE' --title "Remove package" --inputbox "Enter a package's name you want to remove." $hght $wdth 2> $tmp
pckg=$(< $tmp)
    if test $? -eq 0
  	   then
              sudo chroot $Dest/custom apt-get remove --purge --assume-yes "$pckg"
       			if test $? -ne 0
  	   		  then        		  
                            dialog --title 'Error' --msgbox "The $pckg package failed removal\n" $hght $wdth
			    packgmenu                      
       			else
             		    dialog --title 'Done' --infobox "$pckg successfully removed!" $hght $wdth; sleep 3
       		fi
    fi
packgmenu 
}

#Change default background
function changeback() {
 dialog --backtitle "CUSTOMIZE" --title "Use TAB and arrows to move, and SPACE BAR to select" --fselect $HOME/ 18 50 2> $tmp
 imgpath=$(< $tmp)
    if [ -f "$imgpath" ]
    then
      img=$(basename "$imgpath")
     sudo cp $imgpath $Dest/custom/usr/share/backgrounds
     sudo chroot $Dest/custom gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --set -t string /desktop/gnome/background/$img /usr/share/backgrounds/$img
      dialog --title "Background changed!" --msgbox "Background successfully changed with:\n$imgpath" $hght $wdth
    else
      dialog --title "Error" --msgbox "The file\n$imgpath\nis not a valid file." $hght $wdth
    fi
packgmenu
}

#Allow the user to select among different personalizations.
function packgmenu() {
packgmenu_Check=false
dialog --backtitle 'CUSTOMIZE' --title "Choose an option" --menu "You can use the UP/DOWN arrow keys.\nChoose a task or end the customization." 14 65 6 1 "Add new repositories" 2 "Add new packages automatically" 3 "Add a package manually (.deb file)" 4 "Remove an installed package" 5 "Change default background" 6 "End customization" 2> $tmp 
answ=$(< $tmp)

case $answ in
       1) addrepo;;
       2) autoinstll;;
       3) maninstll;;
       4) removepckg;;
       5) changeback;;
       6) clean && exit 0;; #later it will make the iso TODO
       *) quit 'packgmenu';;
esac

packgmenu_Check=true
}


#SCRIPT########################################################################
#Program flow executing above procedures, if a status file is found, resume execution.

instdep 'dialog'
instdep 'squashfs-tools'
instdep 'gawk'

#Resume and redirect according to status file
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
      dialog --title 'Resume' --yesno 'Apparently, this script was already executed before. Would you like to resume execution?\n-Yes to continue execution\n-No to restart script\nIf you choose no, you will not lose your progress in /liveubuntu, but you can restart the customization.' $hght $wdth
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
  fi
welcome


exit 0
