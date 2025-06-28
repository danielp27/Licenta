#!/bin/bash

#În caz că script-ul este întrerupt de erori sau Ctrl-C, se șterg fișierele create
cleanup() {
        echo ""
        echo -e "\nScript-ul a fost întrerupt neașteptat, încercați din nou.\n"
	if [ -f "$site_archive" ]; then
		rm $site_archive
	fi
	if [ -f deploy_site_inside_vm.sh ]; then
		rm deploy_site_inside_vm.sh
	fi
        exit 1
}

trap cleanup INT TERM ERR

trap 'trap - INT TERM ERR' EXIT

while true; do
	read -p "Numele mașinii virtuale: " vm_name
	if minikube kubectl -- get vmi 2>/dev/null | grep -qw "$vm_name"; then
		break
	else
		echo -e "\nMașina virtuală $vm_name nu există, introduceți alta.\n"
	fi
done

echo "Se așteaptă ca pod-ul asociat VM-ului '$vm_name' să fie gata..."
minikube kubectl -- wait pod -l kubevirt.io/domain="$vm_name" \
  --for=condition=Ready --timeout=180s

# Extrage NodePortul mașinii virtuale, care este necesar pentru a o putea accesa
port=$(minikube kubectl -- get svc $vm_name-ssh -o=jsonpath='{.spec.ports[0].nodePort}') 
ip=$(minikube ip)

echo "Se așteaptă ca serviciul SSH să fie disponibil în '$vm_name'..."
until ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
  -i ~/.ssh/id_ed25519 -p "$port" fedora@"$ip" true 2>/dev/null; do
  sleep 2
done

# Se introduce calea site-ului static
read -p "Calea către folderul cu fișierele site-ului (ex. ./mywebsite): " website_folder

# Verifică dacă folderul nu există
if [ ! -d "$website_folder" ]; then
  echo -e "\nFolderul nu există.\n"
  exit 1
fi

site_archive="site-content.tar.gz" 
# Arhivează folderul într-o arhivă tar.gz
tar -czf $site_archive -C "$website_folder" . 

# Trimite folderul arhivat în mașina virtuală
scp -i ~/.ssh/id_ed25519 -P $port $site_archive fedora@$ip:/home/fedora/

# Creează și scrie un script Bash pentru a fi trimis în mașina virtuală care 
# dezarhiveză site-ul în folderul implicit folosit de Nginx și face deploy la acesta în clusterul său Kubernetes
cat <<'EOF' > deploy_site_inside_vm.sh
#!/bin/bash

export KUBECONFIG=/home/fedora/.kube/config

sudo mkdir -p /var/www/html
sudo tar -xzf /home/fedora/site-content.tar.gz -C /var/www/html
sudo chown -R root:root /var/www/html

echo "Se așteaptă până când kubectl devine valabil..."
until command -v kubectl >/dev/null 2>&1; do
  sleep 2
done

echo "Se așteaptă până când API-ul Kubernetes devine valabil..."
until kubectl cluster-info >/dev/null 2>&1; do
  sleep 2
done

kubectl delete deployment nginx-custom --ignore-not-found
kubectl delete svc nginx-custom --ignore-not-found

kubectl apply -f - <<EOL
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-custom
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-custom
  template:
    metadata:
      labels:
        app: nginx-custom
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        hostPath:
          path: /var/www/html
          type: Directory
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-custom
spec:
  selector:
    app: nginx-custom
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: NodePort
EOL
EOF

# Trimite scriptul în mașina virtuală
scp -i ~/.ssh/id_ed25519 -P $port deploy_site_inside_vm.sh fedora@$ip:/home/fedora/
# Face scriptul executabil și îl rulează în interiorul mașinii virtuale
ssh -i ~/.ssh/id_ed25519 -p $port fedora@$ip "chmod +x deploy_site_inside_vm.sh && ./deploy_site_inside_vm.sh"

# Șterge arhiva și scriptul creat de pe host
rm $site_archive
rm deploy_site_inside_vm.sh

# Extrage NodePortul aplicației Nginx
vm_port=$(ssh -i ~/.ssh/id_ed25519 -p $port fedora@$ip "kubectl get svc nginx-custom -o=jsonpath='{.spec.ports[0].nodePort}'")

# Funcție pentru a alege un port liber aleatoriu
pick_free_port() {
  while :; do
    port=$(shuf -i 20000-40000 -n 1)
    ! ss -tuln | grep -q ":$port " && echo $port && return
  done
}

free_port=$(pick_free_port)

echo -e "\nS-a făcut deploy la site personalizat cu nginx.\n"
echo -e "Dacă rulați comanda 'virtctl port-forward vmi/$vm_name $free_port:$vm_port pe host', puteți accesa site-ul de pe dispozitivul dvs. la http://localhost:$free_port.
Portul $free_port este un port liber ales aleatoriu, puteți să alegeți altul dacă doriți.\n"

