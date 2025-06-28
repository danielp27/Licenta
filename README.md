Adresă repository: https://github.com/danielp27/Licenta

Aplicația se rulează într-un sistem Linux.

Pașii de instalare: 
- aplicația folosește următoarele comenzi/programe care trebuie instalat și sau pornite: ssh, curl și docker (mai specific versiunea de linie de comandă sau docker-engine). Aplicația avertizează utilizatorul dacă acestea nu sunt instalate sau pornite, dar doar atât, tot trebuie să faceți asta;
- se descarcă fișierele .sh (adică toate fișierele) din repozitory, fie prin clonare git sau descărcare sub formă de arhivă zip;
- se fac executabile toate fișierele descărcate din acest repository;
- dacă rulați programul într-o mașină virtuală, KubeVirt sugerează să se activeze virtualizarea imbricată (nested virtualization), în acest caz căutați cum să faceți asta pentru sistemul dvs. Dacă nu puteți activa virtualizarea imbricată, KubeVirt sugerează să activați emulare KubeVirt cu comanda: kubectl -n kubevirt patch kubevirt kubevirt --type=merge --patch '{"spec":{"configuration":{"developerConfiguration":{"useEmulation":true}}}}', care se va rula de fiecare dată după ce creați mediul de lucru cu prima opțiune a meniului de opțiuni minikube;
- pentru a utiliza programul se rulează doar scriptul main.sh. 
