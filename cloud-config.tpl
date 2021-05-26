#cloud-config
users:
  - default
  - name: centos
    ssh-authorized-keys:
      - ${public_key}
    #sudo: ALL=(ALL) NOPASSWD:ALL
    #groups: sudo, docker
    shell: /bin/bash
  - name: foobar
    shell: /bin/bash
write_files:
- content: |
    # My new file from cloud-init

    foo
  path: /root/cloudinit.test
