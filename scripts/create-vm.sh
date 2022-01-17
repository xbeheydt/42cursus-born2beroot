#!/bin/bash

# Script settings =============================================================
MANAGER=$(which VBoxManage)
HEADLESS=$(which VBoxHeadless)
VM_NAME=$1
VM_PATH=$2
OS_TYPE=$3
ISO_PATH=$4

VM_NETWORK="vboxnet0"
VM_NETADAP="eth0"
VM_CONTROLLER="SATA Controller"
VM_SIZE=35000 # equal env 35Gb
VM_RDP_PORT=10001


# Helper functions ============================================================
usage()
{
    echo "Usage : create-vm [VM_NAME] [VM_PATH] [OS_TYPE] [ISO_PATH]"
    echo "  VM_NAME     name of VM."
    echo "  VM_PATH     path where store your vm."
    echo "  OS_TYPE     os type wants to install. [eg: Debian_64, ...]"
    echo "  ISO_PATH    path to iso os install."
}

info()
{
    echo "[INFO] - $@"
}

err()
{
    printf "\033[31m"
    echo "[ERROR] - $1"
    printf "\033[0m"
    usage
    exit 1
}


# Main ========================================================================

# Preliminary error tests
[ ! -f "$MANAGER" ]     && err "\"VBoxManage\" not found in PATH or VirtualBox is not install !"
#[ ! -f "$HEADLESS" ]    && err "\"VBoxHeadless\" not found in PATH or VirtualBox is not install !"
[ "$VM_NAME" == "" ]    && err "\"VM_NAME\" must be set !"
[ "$VM_PATH" == "" ]    && err "\"VM_PATH\" must be set !"
[ "$OS_TYPE" == "" ]    && err "\"OS_TYPE\" must be set !"
[ ! -f "$ISO_PATH" ]    && err "ISO \"$ISO_PATH\" not found !"

# VM creation and basics settings
[ ! -d "$VM_PATH" ] && mkdir -p $VM_PATH && info "\"$VM_PATH\" folder was created."
$MANAGER createvm --name $VM_NAME --ostype $OS_TYPE --register --basefolder $VM_PATH
$MANAGER modifyvm $VM_NAME --ioapic on
$MANAGER modifyvm $VM_NAME --memory 1024 --vram 128
info "VM \"$VM_NAME\" create in \"$VM_PATH\"."

# Network settings
#VBOXNET=$($MANAGER list hostonlyifs | grep $VM_NETWORK)
#[ "$VBOXNET" == "" ] && $MANAGER hostonlyif create && info "\"$VM_NETWORK\" create."
#$MANAGER modifyvm "$VM_NAME" --nic1 bridged --hostonlyadapter1 "$VM_NETWORK"
#$MANAGER modifyvm "$VM_NAME" --nic1 bridged --bridgedadapter1 eth0
info "$VM_NAME attached in \"eth0\" network."

# Storage settings
$MANAGER storagectl "$VM_NAME" --name "$VM_CONTROLLER" --add sata --controller IntelAhci
$MANAGER createmedium disk --filename "$VM_PATH/$VM_NAME/$VM_NAME.vdi" --format vdi --size $VM_SIZE --variant Standard
$MANAGER storageattach $VM_NAME --storagectl "$VM_CONTROLLER" --port 0 --device 0 --type hdd --medium "$VM_PATH/$VM_NAME/$VM_NAME.vdi"
$MANAGER storageattach $VM_NAME --storagectl "$VM_CONTROLLER" --port 1 --device 0 --type dvddrive --medium $ISO_PATH
$MANAGER modifyvm $VM_NAME --boot1 dvd --boot2 disk --boot3 none --boot4 none
info "Storage settings complete."

# RDP access
$MANAGER modifyvm $VM_NAME --vrde on --vrdemulticon on --vrdeport $VM_RDP_PORT
info "RDP access activate."

# Nested virtualization
$MANAGER modifyvm $VM_NAME --nested-hw-virt on
info "Nested Hardware Virtualization activate."

echo
info "$VM_NAME complete created !"
echo "Now you can run $VM_NAME in headless mode with command : $HEADLESS --startvm $VM_NAME"