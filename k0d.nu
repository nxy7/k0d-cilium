#!/usr/bin/env nu
use utils.nu

# created k0s cluster in docker
export def create [] {
  cd (utils project-root);
  docker compose -f k0s.compose.yml up -d;

  print "Waiting till cilium becomes available..";
  loop {
    try {
      (docker exec k0s mount -t cgroup2 none /run/cilium/cgroupv2);
    };
   copy-kubeconfig;
    if (
      do { kubectl get ds -n kube-system } | complete | if ($in.exit_code == 0) {$in.stdout} | from ssv | where NAME == cilium | $in.0? | $in != $nothing and $in.DESIRED == $in.READY != 0
    ) {
      break;
    }
      sleep 1sec;
  }
  
  

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
