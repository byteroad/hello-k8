# INSTALL

This guide is for the installation of the underlying software in the kubernetes cluster. For installing the OGC API infrastructure, please refer to [README.md](README.md).

## For All Nodes

Install containerd:

    sudo apt-get update
    sudo apt-get install -y containerd

    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml

    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    sudo systemctl restart containerd
    sudo systemctl enable containerd

Install Kubernetes components:

    sudo apt update && sudo apt install -y apt-transport-https curl

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt update

    sudo apt install -y kubelet kubeadm
    sudo apt-mark hold kubelet kubeadm

    # Master node only
    sudo apt install -y kubectl
    sudo apt-mark hold kubectl
    kubectl version --client

Disable the swap on Ubuntu:

    sudo swapoff -a
    sudo nano /etc/fstab
    Comment line:
    /swap.img    none    swap    sw    0    0 ->    #/swap.img    none    swap    sw    0    0

IP forwarding for kube-proxy:

    sudo modprobe br_netfilter

    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf > /dev/null
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward                 = 1
    EOF
    sudo sysctl --system

## On Master Node only:

    sudo kubeadm init --pod-network-cidr=10.244.0.0/16

Take note of the last command in the output of this command, that tells you the join command (example bellow):

    Then you can join any number of worker nodes by running the following on each as root:

    kubeadm join 192.168.2.41:6443 --token l2gyp6.443v2uzkcdrp5bbk \
        --discovery-token-ca-cert-hash sha256:9519d2911cf4afbfba32e9b4944e180e40bc8fb10e7073e8813d17dcfb15ebd7 

To start using your cluster, you need to run the following as a regular user:

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster. Use flanel as network plugin:

    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

Open the port 6443 on firewall:

    sudo ufw allow 6443/tcp

At this point, you can check the nodes running (at this point, one):

    byteroad@vmintergeo1:~$ kubectl get nodes
    NAME          STATUS   ROLES           AGE   VERSION
    vmintergeo1   Ready    control-plane   15m   v1.30.14

    byteroad@vmintergeo1:~$ kubectl get pods -n kube-system
    NAME                                  READY   STATUS    RESTARTS   AGE
    coredns-55cb58b774-m4h2c              1/1     Running   0          15m
    coredns-55cb58b774-whmjm              1/1     Running   0          15m
    etcd-vmintergeo1                      1/1     Running   0          15m
    kube-apiserver-vmintergeo1            1/1     Running   0          15m
    kube-controller-manager-vmintergeo1   1/1     Running   0          15m
    kube-proxy-n2kq9                      1/1     Running   0          15m
    kube-scheduler-vmintergeo1            1/1     Running   0          15m

Install kustomize (replace `YOUR_GITHUB_TOKEN` with your actual GitHub token):

    export GITHUB_TOKEN=YOUR_GITHUB_TOKEN
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

    sudo mv kustomize /usr/local/bin

## On Worker Nodes only:

Paste the join command outputed by the init command of the master node, preceeded by sudo (example bellow):

    kubeadm join 192.168.2.41:6443 --token l2gyp6.443v2uzkcdrp5bbk \
        --discovery-token-ca-cert-hash sha256:9519d2911cf4afbfba32e9b4944e180e40bc8fb10e7073e8813d17dcfb15ebd7 

(run again the `kubectl get nodes` and `kubectl get pods -n kube-system` on the master node, to see it joining)
