#!/bin/bash
#@Author: eciprian Matr.N 10154
#This script use dialogs to personalize your Ubuntu 12.04 iso installation.

#SETTINGS########################################################################
wdth=60 #default dialog width and height
hght=20

status=/tmp/status #filepath for keeping score of script current status
tmp=/tmp/answ #filepath for processing selections of the user
Dest=$HOME/liveubuntueciprian #directory path for directing exctracted iso
DESTMP=/tmp/liveubuntueciprian/ #directory path for temporary mounting
isopath_save=/tmp/isopath_save

depend_Check=false
getiso_Check=false
mountext_Check=false
changeroot_Check=false
allowmultiverse_Check=false
packgmenu_Check=false
updatemenu_Check=false
finalize_Check=false


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
		
if $finalize_Check
  then 
  echo "Before exit files in $Dest, if present, will be deleted... Confirm? (y/n)\n"
  read Answ
   if test "$Answ" = "y"
     then
       sudo rm -rf $Dest
   fi
fi
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
  then dialog --title "Workspace found!" --yesno "There is already a /liveubuntueciprian folder in your home directory, do you want to keep it and continue working with it?\n" $hght $wdth
       case $? in
                0) echo "changeroot" >> $status
                   mountext_Check=true   
                   changeroot
                   ;;           
		1) mount | grep --silent "$HOME/liveubuntueciprian/squashfs"
                   if [  $? -eq 0 ]
		      then sudo umount -fld $Dest/squashfs
                   fi
		   sudo chroot $Dest/custom umount /dev/pts/ > /dev/null
 		   sudo chroot $Dest/custom umount /proc/ > /dev/null
 		   sudo chroot $Dest/custom umount /sys/ > /dev/null
 		   sudo umount $Dest/custom/dev > /dev/null
		   sudo rm -rf $Dest
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
                  mount | grep "$HOME/liveubuntueciprian/squashfs"
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
       0) sudo chroot $Dest/custom mount -t proc none /proc/ > /dev/null
	  sudo chroot $Dest/custom mount -t sysfs none /sys/ > /dev/null
 	  sudo chroot $Dest/custom mount -t devpts none /dev/pts > /dev/null
	  sudo mount --bind /dev/ $Dest/custom/dev
			;;
       1|255) quit 'changeroot';;
esac

changeroot_Check=true
echo "allowmultiverse" >> $status
allowmultiverse
}

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
              if test  $? -ne 0
		then
		   dialog --title 'Error' --msgbox "The apt failed to update, maybe your internet connection is not working.\nTry again." $hght $wdth
		   allowmultiverse
	      fi
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

#Select a .deb file and install it with dependecies
function maninstll() {
dialog --backtitle 'CUSTOMIZE' --title "Select the .deb file" --fselect $HOME/ 14 48 2> $tmp
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
 dialog --backtitle "CUSTOMIZE" --title "Use TAB and arrows to move, and SPACE BAR to select" --fselect $HOME/ 14 48 2> $tmp
 imgpath=$(< $tmp)
    if [ -f "$imgpath" ]
    then
      img=$(basename "$imgpath")
     sudo cp $imgpath $Dest/custom/usr/share/backgrounds
     sudo chroot $Dest/custom gconftool-2 --direct --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults --set -t string /desktop/gnome/background/picture_filename /usr/share/backgrounds/$img
      dialog --title "Background changed!" --msgbox "Background successfully changed with:\n$imgpath" $hght $wdth
    else
      dialog --title "Error" --msgbox "The file\n$imgpath\nis not a valid file." $hght $wdth
    fi
packgmenu
}

#Upgrade the whole Ubuntu iso to latest distro
function upgrade() {
dialog --title "You sure?" --yesno "This process will download a new distribution and install it.\nIt will need a lot of time, do you want to continue?" $hght $wdth
if test $? -ne 0
	then updatemenu
fi
sudo chroot $Dest/custom apt-get update
sudo chroot $Dest/custom apt-get --assume-yes upgrade
sudo chroot $Dest/custom apt-get dist-upgrade
sudo chroot $Dest/custom apt-get install update-manager-core
sudo chroot $Dest/custom do-release-upgrade
if test $? -ne 0
then
      dialog --infobox "The update process did not end as expected, please retry" $hght $wdth ; sleep 2
else
      dialog --infobox "Upgrade completed!" $hght $wdth ; sleep 2
fi
updatemenu
}

#Update package automatically
function upgradepckg() {
dialog --backtitle 'CUSTOMIZE' --title "Upgrade a Package automatically" --inputbox "Enter a package name.\nMake sure your internet connection is working and you have added the required PPA, if necessary." $hght $wdth 2> $tmp
    if test $? -eq 0
  	   then
	      pckg=$(< $tmp)
              sudo chroot $Dest/custom apt-get install --assume-yes "$pckg"
       			if test $? -ne 0
  	   		  then        		  
                            dialog --title 'Error' --msgbox "The $pckg package failed upgrade\n" $hght $wdth
			    updatemenu                      
       			else
             		    dialog --title 'Done' --infobox "$pckg successfully upgraded!" $hght $wdth; sleep 3
       			fi
    fi
updatemenu 
}


function makeiso(){
echo "Creating actual iso file..."
		cd $Dest/cd &&
		sudo mkisofs -r -V "Ubuntu-$isoname" -b isolinux/isolinux.bin -c isolinux/boot.cat -cache-inodes -J -l -no-emul-boot -boot-load-size 4 -boot-info-table -o $HOME/Ubuntu-$isoname.iso .
		if test  $? -ne 0
		then
		   dialog --title 'Error' --yesno "The creation of the iso failed.\nThe necessary files are still in your:\n$HOME/liveubuntu/cd.\nWould you try again?" $hght $wdth
		   if test  $? -ne 0
		      then
 		        exit -1
		   else
                        makeiso
                   fi
	      fi
}

#Finalize and make the iso
function finalize() {
finalize_Check=false
dialog --title 'Warning' --msgbox "This process will require some time to output the iso. Do you want to continue? " $hght $wdth
 if test $? -ne 0
  	   then updatemenu
 fi

dialog --backtitle 'FINALIZE' --title "Make the Iso" --inputbox "Enter the name of the new iso" $hght $wdth 2> $tmp

if test $? -eq 0
  	   then 
		isoname=$(< $tmp)
		echo "Cleaning up temp files and apt-get..."
     		sudo chroot $Dest/custom sudo rm -f /etc/hosts /etc/resolv.conf
		sudo chroot $Dest/custom apt-get clean
		sudo chroot $Dest/custom umount /dev/pts/ > /dev/null
 		sudo chroot $Dest/custom umount /proc/ > /dev/null
 		sudo chroot $Dest/custom umount /sys/ > /dev/null
 		sudo umount $Dest/custom/dev > /dev/null
		changeroot_Check=false
		
		echo "Generating manifest file..."
		sudo chmod +w $Dest/cd/casper/filesystem.manifest
		sudo chroot $Dest/custom dpkg-query -W --showformat='${Package} ${Version}\n' > $Dest/cd/casper/filesystem.manifest
		sudo cp $Dest/cd/casper/filesystem.manifest $Dest/cd/casper/filesystem.manifest-desktop

		echo "Regenerating the squashfs.."
		sudo mksquashfs $Dest/custom $Dest/cd/casper/filesystem.squashfs
		
		echo "Updating Md5 sums..."
		[ -f $Dest/cd/md5sum.txt ] && sudo rm $Dest/cd/md5sum.txt
		cd $Dest/cd && sudo find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | udo tee md5sum.txt
		
                makeiso
		
		finalize_Check=true
		dialog --title "Thank you" --msgbox "The script is ended, you will find the new iso in:\n $HOME/Ubuntu-$isoname.iso" $hght $wdth
	        clean
                exit 0

else updatemenu
fi

}

#Show the upgrade options menu
function updatemenu() {
updatemenu_Check=false
dialog --backtitle 'UPGRADE' --title "Choose an option" --menu "You can use the UP/DOWN arrow keys.\nChoose a task or end the upgrade." 14 65 3 1 "Upgrade Ubuntu" 2 "Upgrade a package" 3 "End and make the Iso" 2> $tmp 
answ=$(< $tmp)

case $answ in
       1) upgrade;;
       2) upgradepckg;;
       3) finalize;;
       *) quit 'updatemenu';;
esac

echo "updatemenu" >> $status
updatemenu_Check=true
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
       6) echo "updatemenu" >> $status
          updatemenu;; 
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
[ -f $status ] && phases_Check=$( gawk '{ print $1 }' $status ) #load completed phases
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
      dialog --title 'Resume' --yesno "Apparently, this script was already executed before. Would you like to resume execution?\n-Yes to continue execution\n-No to restart script\nIf you choose no, you will not lose your progress stored in $Dest, but you can restart the customization." $hght $wdth
      if [ $? -eq 0 ]
        then 
        case $start in  #branch to last undone phase
           welcome) welcome;;
	   getiso) getiso;;
 	   mountext) mountext;;
	   changeroot) changeroot;;
	   allowmultiverse) allowmultiverse;;
           packgmenu) packgmenu;;
	   updatemenu) updatemenu;;
	 esac  
       fi
      clean	
  fi
welcome


exit 0
