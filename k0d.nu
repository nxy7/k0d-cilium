#!/usr/bin/env nu
use utils.nu

# created k0s cluster in docker
export def create [] {
  cd (utils project-root);
  docker compose -f k0s.compose.yml up -d;

  print "waiting till k0s becomes available";
  loop {
    copy-kubeconfig;
    if ((do {kubectl get all} | str contains service/kubernetes) == true) {
      print "cluster ready for futhurer setup";
      break;
    }
    # print "sleep"
    sleep 1sec;
  }
  
  try {
    docker exec k0s mount -t cgroup2 none /run/cilium/cgroupv2;
  };

  try {
    let regConfig = 'version = 2
[plugins]
[plugins."io.containerd.grpc.v1.cri"]
[plugins."io.containerd.grpc.v1.cri".registry]
[plugins."io.containerd.grpc.v1.cri".registry.mirrors]
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."noxy.ddns.net:5000"]
  endpoint = ["http://noxy.ddns.net:5000"]
[plugins."io.containerd.grpc.v1.cri".registry.configs]
[plugins."io.containerd.grpc.v1.cri".registry.configs."noxy.ddns.net:5000"]
[plugins."io.containerd.grpc.v1.cri".registry.configs."noxy.ddns.net:5000".tls]
  insecure_skip_verify = true'
      let commandString = $"\"echo '($regConfig)' >> /etc/k0s/containerd.toml\""
      (docker exec k0s /bin/bash -c $commandString) | complete | print
  };
  

  kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml


   kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml;
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml;
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml;
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml;
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml;

  init-cert-manager
}

# created k0s cluster in docker
export def copy-kubeconfig [] {
  do { docker exec k0s cat /var/lib/k0s/pki/admin.conf | save ~/.kube/config --force }
}

# deletes k0s cluster
export def delete [] {
  cd (utils project-root)
  docker compose -f k0s.compose.yml down
}

export def init-cert-manager [] {
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.crds.yaml
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    kubectl create ns cert-manager
    helm install cert-manager --namespace cert-manager jetstack/cert-manager
}
