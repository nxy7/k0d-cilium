#!/usr/bin/env bash
# Include utils.sh if you have utility functions, similar to `use utils.nu`

main() {
  restart
}

restart() {
  delete
  create
}

create() {
  cd $(project_root)  # Replace with actual function if needed
  docker compose -f k0s.compose.yml up -d

  echo "Waiting till cilium becomes available.."
  while true; do
    copy_kubeconfig
    docker exec k0s mount -t cgroup2 none /run/cilium/cgroupv2 || true

    if kubectl get svc | grep -q "kubernetes"; then
      break
    fi
    sleep 1
  done

  regConfig='...your big config here...'
  docker exec k0s /bin/bash -c "echo '$regConfig' >> /etc/k0s/containerd.toml"

  kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
  init_cert_manager
  kubectl apply -f pool.yaml
  kubectl apply -f bgppolicy.yaml
}

copy_kubeconfig() {
  docker exec k0s cat /var/lib/k0s/pki/admin.conf > ~/.kube/config
}

delete() {
  cd $(project_root)  # Replace with actual function if needed
  docker compose -f k0s.compose.yml down
}

init_cert_manager() {
  # kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.crds.yaml
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  helm install cert-manager \
    --version v1.10.0 \
    --namespace cert-manager \
    --set installCRDs=true \
    --create-namespace \
    --set "extraArgs={--feature-gates=ExperimentalGatewayAPISupport=true}" \
    jetstack/cert-manager
}

project_root() {
  # Check if .git folder is in current directory
  ls -a | grep -q ".git"
  
  # $? stores the exit code of the last command. If grep finds ".git", $? will be 0
  if [ $? -ne 0 ]; then
    cd ..

    current_path=$(pwd)
    
    if [ "$current_path" == "/" ]; then
      echo "Got to filesystem root without encountering .git" >&2
      exit 1
    fi

    project_root
  else
    pwd
  fi
}


# Entry point
main
