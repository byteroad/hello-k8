# Reset kubernetes components
sudo kubeadm reset -f

# Clean up networking
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Remove CNI conf
sudo rm -rf /etc/cni/net.d

# Delete the CNI virtual interfaces
sudo ip link delete flannel.1 || true
sudo ip link delete cni0 || true

# You should reboot now
echo "Master node has been reset. Please reboot now"