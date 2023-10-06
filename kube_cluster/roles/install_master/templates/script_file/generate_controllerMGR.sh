cd /opt/k8s/kubernetes/ssl/

KUBE_CONFIG="/opt/k8s/kubernetes/cfg/kube-controller-manager.kubeconfig"
KUBE_APISERVER="https://{{ansible_default_ipv4.address}}:6443"

kubectl config set-cluster kubernetes \
  --certificate-authority=/opt/k8s/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials kube-controller-manager \
  --client-certificate=./kube-controller-manager.pem \
  --client-key=./kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-controller-manager \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
