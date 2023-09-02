#!/usr/bin/env nu
use utils.nu

export def main [] {
  restart
}

export def restart [] {
  delete
  create
}

# created k0s cluster in docker
export def create [] {
  cd (utils project-root);
  docker compose -f k0s.compose.yml up -d;

  print "Waiting till cilium becomes available..";
  loop {
    try {
      let _ = copy-kubeconfig;
    
      if (
        do { kubectl get svc } | complete | $in.exit_code == 0
      ) {
        print "Cluster is ready for futher instructions.."
        break;
      }
      sleep 1sec;
    }
  }
  let _ = mount-cgroupv2;
  let _ = install-gateway-crds
  
    # add-insecure-registry  

    let _ = kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml;
    init-cert-manager;
    kubectl apply -f pool.yaml;
    kubectl apply -f l2announcment.yaml;
    # kubectl apply -f bgppolicy.yaml;
  
  print "cluster initiated"
}

# created k0s cluster in docker
export def copy-kubeconfig [] {
  try {
    do { docker exec k0s cat /var/lib/k0s/pki/admin.conf | save ~/.kube/config --force } | complete
  }
}

# deletes k0s cluster
export def delete [] {
  cd (utils project-root)
  docker compose -f k0s.compose.yml down --remove-orphans
}

export def mount-cgroupv2 [] {
  try {
    do {docker exec k0s mount -t cgroup2 none /run/cilium/cgroupv2} | complete
  };

}

export def add-insecure-registry [] {
    let regConfig = 'version = 2
imports = [
  "/run/k0s/containerd-cri.toml",
]
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
      let commandString = $"\"echo '($regConfig)' > /etc/k0s/containerd.toml\""
      do {docker exec k0s-worker1 /bin/bash -c $commandString} | complete | print
      do {docker exec k0s /bin/bash -c $commandString} | complete | print
  
}

def install-gateway-crds [] {
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
  kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
  print "gateway crds installed"
}

export def init-cert-manager [] {
    # kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.crds.yaml
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    (helm install cert-manager 
      --version v1.10.0
      --namespace cert-manager 
      --set installCRDs=true
      --create-namespace
      --set "extraArgs={--feature-gates=ExperimentalGatewayAPISupport=true}"
      jetstack/cert-manager)
}
