---
title: "Cgroupsv2"
date: 2024-09-08T14:35:46+02:00
draft: true
---

Sembra non esserci molta documentazione riguardo all'utilizzo dei cgroup.
Questi contribuiscono all'implementazione della tecnologia dei container,
e di conseguenza vengono associati al mondo dei container e basta, passando un po' in sordina.

I cgroups da soli possono essere utilizzati sia programmaticamente che tramite shell
da un amministratore skillato, per inviare segnali a tutti i processi e sottoprocessi,
stabilire limiti sul consumo di risorse, avere visibilità sullo stato di utilizzo ed altri.

Nel resto di questo documento proverò a raccogliere una serie di risorse
riguardanti l'utilizzo dei cgroups.

## Documentation/admin-guide/cgroup-v2.rst
L'ultima parola su come funzionano i cgroup è il codice che li implementa, ma se
non si ha la pazienza, i maintainer di questo subsystem ci forniscono anche un documento
.rst nel tree del kernel.

Esistono delle pagine online che mostrano questo documento, ma la versione qui è importante:
vogliamo vedere il documento che riguarda la nostra versione del kernel.
Presso la maggior parte delle distro Linux (credo) dovrebbe poter essere possibile
tirare giù la documentazione relativa alla nostra versione del kernel tramite
pacchetto, con nomi come **kernel-doc** (su Fedora).

Una volta tirato giù il pacchetto di riferimento:   
**find /usr/share/doc/kernel-doc-6.10.7-200/Documentation -iname "*cgroup*"**   
una command line simile a quella sopra, ci tirerà fuori tutti i file con cgroup nel nome (case insensitive).