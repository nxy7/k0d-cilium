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
  load-kernel-modules

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
  
  let _ = kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml;
  init-cert-manager;
  kubectl apply -f pool.yaml;
  # fix-gtw-addr
  kubectl apply -f l2announcment.yaml;
  
  print "cluster initiated"
}

# created k0s cluster in docker
export def copy-kubeconfig [] {
  try {
    do { docker exec k0s cat /var/lib/k0s/pki/admin.conf | save ~/.kube/config --force } | complete
  }
}

# cilium requires some kernel modules to be preloaded
export def load-kernel-modules [] {
  sudo modprobe ip6table_filter -v
  sudo modprobe iptable_raw -v
  sudo modprobe iptable_nat -v
  sudo modprobe iptable_filter -v
  sudo modprobe iptable_mangle -v
  sudo modprobe ip_set -v
  sudo modprobe ip_set_hash_ip -v
  sudo modprobe xt_socket -v
  sudo modprobe xt_mark -v
  sudo modprobe xt_set -v
}

# deletes k0s cluster
export def delete [] {
  cd (utils project-root)
  docker compose -f k0s.compose.yml down --remove-orphans
}


# export def mount-cgroupv2 [] {
#   try {
#     do {docker exec k0s mount --make-shared -t cgroup2 none /run/cilium/cgroupv2} | complete
#   };
# }
export def mount-cgroupv2 [] {
  try {
    do {
      sudo mkdir -p /run/cilium/cgroupv2
      sudo mount --bind -t cgroup2 /run/cilium/cgroupv2 /run/cilium/cgroupv2
      sudo mount --make-shared /run/cilium/cgroupv2
      print "Done mounting cgroupv2"
    } | complete
  }
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

export def install-gateway-crds [] {
  let manifests = [
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml"
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml"
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml"
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml"
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.1/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"    
  ]
  $manifests | par-each { kubectl apply -f $in } 
  # kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v0.8.0/standard-install.yaml
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

    kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/servicemesh/ca-issuer.yaml
}

export def fix-gtw-addr [] {
  kubectl delete -f pool.yaml; kubectl apply -f pool.yaml
  kubectl get gtw -A | from ssv | get 0 | if ($in.ADDRESS != "172.17.0.2") {print "Fixing gtw address"; fix-gtw-addr;} else {print "Gateway ready"}
}
