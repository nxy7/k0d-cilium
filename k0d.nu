#!/usr/bin/env nu
use utils.nu

# restarts k0d cluster
export def main [] {
  restart
}

export def restart [] {
  delete
  create
}

# created k0s cluster in docker
export def create [] {
  use k8s_utils/kubernetes.nu;
  kubernetes load-kernel-modules

  cd (utils project-root);
  docker compose -f k0s.compose.yml up -d;

  wait-for-cluster
  mount-cgroupv2;
  print "Cluster ready.."

  enter k8s_utils
  kubernetes install-gateway-crds
  kubernetes install-cilium
  kubernetes install-openebs
  kubernetes install-certmanager
  dexit

  kubectl apply -f gateway.yaml
  ./k8s_utils/annotate-gateways.nu --ip 172.17.0.2 --ipPool 172.17.0.2/24
  
}

export def wait-for-cluster [] {
  print "Waiting till cluster becomes available..";
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
