# My findings
while trying to use k0s for development, I've found that it's really hard to make it work nicely inside containers. Single node setup was not working due to [this issue](https://github.com/cilium/cilium/issues/20942) and multi node setup ended up not working out because of cgroups. As far as I understand each node needs to be a part of different cgroup namespace, but if I set `cgroup: private` inside compose it would not start at all.

Spin up k0s cluster inside docker

### Prerequisites
- docker
- bash
- kubectl

And I strongly recommend
- nushell
as bash script might be lagging behind and be updated less frequently

```bash
  # with nushell
  ./k0d.nu
  # with bash
  ./k0d.sh
```
