# Reset kubernetes components
sudo kubeadm reset -f

# Clean up networking
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Remove CNI conf
sudo rm -rf /etc/cni/net.d

# Delete the old Flannel interface if it exists
sudo ip link delete flannel.1 || true

# Cleanup kubeconfig file
rm -rf $HOME/.kube

# You should reboot now
echo "Master node has been reset. Please reboot now"
