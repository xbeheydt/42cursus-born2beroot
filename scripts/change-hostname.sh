HOST_NAME=$1

echo "$HOST_NAME" > /etc/hostname
OLD_HOST_NAME=$(awk '$1=="127.0.1.1" {print $2}' /etc/hosts)
sed -i "s/${OLD_HOST_NAME}/${HOST_NAME}/g" /etc/hosts

echo "Hostname is updated. Reboot for take effect."
