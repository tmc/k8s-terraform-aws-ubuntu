output "kubernetes-api-server" {
  value = "https://${aws_eip.kubernetes-master.public_ip}"
}
output "kubernetes-api-server-credentials" {
  value = "admin:${var.KUBE_PASSWORD}"
}
output "kubectl configuration" {
value = <<EOF
ssh ubuntu@${aws_eip.kubernetes-master.public_ip} 'sudo cat /srv/kubernetes/ca.crt' > ca.crt
ssh ubuntu@${aws_eip.kubernetes-master.public_ip} 'sudo cat /srv/kubernetes/kubecfg.crt' > kubecfg.crt
ssh ubuntu@${aws_eip.kubernetes-master.public_ip} 'sudo cat /srv/kubernetes/kubecfg.key' > kubecfg.key

kubectl config set-cluster ${var.CLUSTER_ID} --server=https://${aws_eip.kubernetes-master.public_ip} --certificate-authority=ca.crt --embed-certs=true
kubectl config set-credentials ${var.CLUSTER_ID} --username=admin --password='${var.KUBE_PASSWORD}' --client-certificate=kubecfg.crt --client-key=kubecfg.key --embed-certs=true
kubectl config set-context ${var.CLUSTER_ID} --cluster=${var.CLUSTER_ID} --user=${var.CLUSTER_ID}
kubectl config use-context ${var.CLUSTER_ID}
rm ca.crt kubecfg.crt kubecfg.key

kubectl cluster-info
EOF
}
