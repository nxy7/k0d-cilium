#!/usr/bin/env nu
use utils.nu

# created k0s cluster in docker
export def create [] {
  cd (utils project-root)
  docker compose -f k0s.compose.yml up -d
}

# created k0s cluster in docker
export def copy-kubeconfig [] {
  docker exec k0s cat /var/lib/k0s/pki/admin.conf | save ~/.kube/config --force
}

# created k0s cluster in docker
export def shell-into [] {
  docker exec -it k0s /bin/sh
}

# deletes k0s cluster
export def delete [] {
  cd (utils project-root)
  docker compose -f k0s.compose.yml down
}
