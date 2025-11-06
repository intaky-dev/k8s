apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://${server_ip}:${server_port}
  name: k3s-cluster
contexts:
- context:
    cluster: k3s-cluster
    user: k3s-admin
  name: k3s
current-context: k3s
users:
- name: k3s-admin
  user:
    client-certificate-data: ""
    client-key-data: ""
