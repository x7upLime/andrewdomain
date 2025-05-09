---
title: "Letsencrypt_cert Manager_openshift"
date: 2024-09-14T15:13:21+02:00
draft: true
---

Ho setuppato 3 managed zones con delegation.
Nel top domain,
  + settare un record NS per il top domain
  + settare un record NS per il subdomain
  + settare un record NS per l'altro subdomain
  + ! spostare eventualmente dei record dal top alla sub di competenza. Altrimenti non funziona.

Ho fatto una cazzata, perchè bastava specificare quale zona usare per ciascun risolutore:
```
  1 kind: ClusterIssuer        
  2 apiVersion: cert-manager.io/v1
  3 metadata:                  
  4  name: letsecrypt-gcloud--x7uplime-monster
  5 spec:                      
  6   acme:                    
  7     email: andreitudor.corduneanu@gmail.com
  8     server: https://acme-staging-v02.api.letsencrypt.org/directory
  9     privateKeySecretRef:   
 10       name: ca-private     
 11     solvers:               
 12     - dns01:               
 13         cloudDNS:          
 14           project: ocp4-cluster
 15           hostedZoneName: x7uplime-monster
 16           serviceAccountSecretRef:
 17             name: ocp4-master-sa
 18             key: key.json  
 19       selector:            
 20         dnsZones:          
 21           - x7uplime.monster
 22     - dns01:               
 23         cloudDNS:          
 24           project: ocp4-cluster
 25           hostedZoneName: x7uplime-monster
 26           serviceAccountSecretRef:
 27             name: ocp4-master-sa
 28             key: key.json  
 29       selector:            
 30         dnsZones:          
 31           - ocp4.x7uplime.monster
 32     - dns01:               
 33         cloudDNS:          
 34           project: ocp4-cluster
 35           hostedZoneName: x7uplime-monster
 36           serviceAccountSecretRef:
 37             name: ocp4-master-sa
 38             key: key.json  
 39       selector:            
 40         dnsZones:          
 41           - apps.ocp4.x7uplime.monster
```

https://letsdebug.net/ - Per verificare una DNS01 Challenge come lo farebbe LetsEncrypt.

## Lo staging di LetsEncrypt
Anche se tutti gli step sono stati effettuati correttamente fino a questo punto:
i certificati vengono correttamente emessi dai server di LetsEcrypt e siamo riusciti
ad incastonarli come gemme negli incavi dei nostri endpoint del cluster,
non saranno comunque riconosciuti dai browser o sistemi operativi.

Fin'ora abbiamo utilizzato gli endpoint di **staging** di LetsEncrypt per emettere i nostri
certificati. Staging, come "non produzione", ovvero non ufficiali.  
Maggiori informazioni nella [documentazione ufficiale di LetsEncrypt](https://letsencrypt.org/docs/staging-environment/)

Quello che abbiamo fatto, ignorandone la ragione o meno, è considerata un'ottima pratica da seguire,
per non appesantire i server di produzione di LetsEncrypt mentre noi siamo effettivamente in fase di testing,
ed evitare di incorrere in rate limit del provider.

I server di produzione li troviamo su https://acme-v02.api.letsencrypt.org/directory

È il momento di cambiare i puntamenti nelle risorse del nostro ClusterIssuer.    
Magari creiamo un overlay di produzione nella nostra kustomization 🤔