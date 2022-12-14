#!/bin/bash
clear
install_text="
░█████╗░██████╗░░█████╗░██╗░░██╗
██╔══██╗██╔══██╗██╔══██╗██║░░██║
███████║██████╔╝██║░░╚═╝███████║
██╔══██║██╔══██╗██║░░██╗██╔══██║
██║░░██║██║░░██║╚█████╔╝██║░░██║
╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝

██╗███╗░░██╗░██████╗████████╗░█████╗░██╗░░░░░██╗░░░░░
██║████╗░██║██╔════╝╚══██╔══╝██╔══██╗██║░░░░░██║░░░░░
██║██╔██╗██║╚█████╗░░░░██║░░░███████║██║░░░░░██║░░░░░
██║██║╚████║░╚═══██╗░░░██║░░░██╔══██║██║░░░░░██║░░░░░
██║██║░╚███║██████╔╝░░░██║░░░██║░░██║███████╗███████╗
╚═╝╚═╝░░╚══╝╚═════╝░░░░╚═╝░░░╚═╝░░╚═╝╚══════╝╚══════╝

░██████╗░█████╗░██████╗░██╗██████╗░████████╗
██╔════╝██╔══██╗██╔══██╗██║██╔══██╗╚══██╔══╝
╚█████╗░██║░░╚═╝██████╔╝██║██████╔╝░░░██║░░░
░╚═══██╗██║░░██╗██╔══██╗██║██╔═══╝░░░░██║░░░
██████╔╝╚█████╔╝██║░░██║██║██║░░░░░░░░██║░░░
╚═════╝░░╚════╝░╚═╝░░╚═╝╚═╝╚═╝░░░░░░░░╚═╝░░░"

echo $install_text
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 5/" /etc/pacman.conf

loadkeys us
timedatectl set-ntp true
pkgs="base linux linux-firmware linux-headers neovim opendoas networkmanager "

curl -fLo /tmp/configuration-script.sh https://raw.githubusercontent.com/KanishakVaidya/arch-KVOS/main/configuration-script.sh
clear
echo $install_text
echo "Do you want to install grub bootloader?"
select yn in "Yes, install grub" "No, don't install grub"
do
    case $yn in
        "Yes, install grub" )
            grubanswer="y"
            pkgs+="grub os-prober "
            if [ -d /sys/firmware/efi ]
            then
                pkgs+="efibootmgr "
                bios="UEFI"
                echo "You have an $bios system"
                echo "You have to create an EFI system partition"
                echo "Create a swap partition if you want one"
                read -p "press enter to continue "
            else
                bios="BIOS"
                echo "You have a $bios system."
                echo "Create a bios boot partition for GPT. No need for separate boot partition for MBR"
                echo "Create a swap partition if you want one"
                read -p "press enter to continue "
            fi
            break
            ;;
        "No, don't install grub" )
            grubanswer="n"
            break
            ;;
        * ) echo "Please enter either 1 or 2" ;;
    esac
done

clear
echo $install_text
lsblk
echo -e "\n"
read -p "Enter the drive (e.g. /dev/sda or /dev/nvme0n1): " drive
cfdisk $drive

clear
echo $install_text
lsblk
echo -e "\n"
read -p "Enter the root partition (e.g. /dev/sda2 or /dev/nvme0n1p2): " partition
mkfs.ext4 $partition
mount $partition /mnt

clear
echo $install_text
if [[ $grubanswer == "y" ]]
then
    if [[ $bios == "UEFI" ]]
    then
        lsblk
        echo -e "\n"
        read -p "Enter EFI partition (e.g. /dev/sda1 or /dev/nvme0n1p1): " efipartition
        mkfs.fat -F 32 $efipartition
        mount --mkdir $efipartition /mnt/boot
    fi
    sed --expression "2s|^|grubanswer=$grubanswer\nbios=$bios\ndrive=$drive\n|" /tmp/configuration-script.sh > /mnt/configuration-script.sh
else
    sed --expression "2s|^|grubanswer=$grubanswer\nbios=\"not installing\"\ndrive=$drive\n|" /tmp/configuration-script.sh > /mnt/configuration-script.sh
fi

clear
echo $install_text
read -p "Create swap partition? [y/n]: " swpanswer
if [[ $swpanswer = y ]] ; then
    lsblk
    echo -e "\n"
    read -p "Enter swap partition (e.g. /dev/sda3 or /dev/nvme0n1p3): " swap_partition
    mkswap $swap_partition
    swapon $swap_partition
fi

clear
echo $install_text

noerror='n'
while [[ $noerror != 'y'  ]]
do
    pacstrap /mnt $(echo $pkgs)
    read -p "Installation ended successfully? (y/n): " noerror
done

clear
echo $install_text
echo -e "\n Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "copying configuration script..."

chmod +x /mnt/configuration-script.sh

arch-chroot /mnt ./configuration-script.sh

[[ $bios == "UEFI" ]] && umount /mnt/boot
umount /mnt
