---
title: "cgroups_fork-bomb"
description: "Mitigare una fork bomb tramite l'uso di cgroups"
date: 2024-09-08T19:53:16+02:00
draft: False
tags:
  - cgroups
---

La command line che vado a mostrarvi non è materiale accademico,
è forse più parte della cultura underground del mondo unix: 

`:() { :|:& };:` -- la fork bomb di Bash

> su bash questa command line viene interpretata come
la definzione di una funzione chiamata ':', il cui corpo prevede
una chiamata a se stessa ed una seconda chiamata in ascolto
sull'input della prima (che non arriva mai) per bloccare il process e impedirgli di uscire,
il tutto in background.  
>  
> L'idea è che al lancio il processo continuerà
a forkare copie che a loro volta forkeranno copie, all'infinito ed in maniera incontrollabile
in quanto ogni processo è indipendente (non basta eliminare un processo parent per fermare il flusso),
fino all'esaurimento dei PID del sistema, risultando nell'incapacità di generare nuovi processi:
niente nuove connessioni ssh, niente nuovi worker apache, niente command line per risolvere il problema.

La fork bomb metteva in ginocchio i sistemi Linux nelle versioni più vecchie.
Ad oggi esiste una migliore gestione delle risorse di sistema e diversi meccanismi per
mitigare questo specifico attacco. Di seguito vado a mostrare uno scenario dove questo
attacco viene reso completamente inoffensivo, tramite i **cgroup**.

Apriamo qualche terminale: una shell per setuppare lo scenario,
una shell per generare la fork bomb, e magari una terza shell per rimanere in osservazione.

1a shell:  
**sudo -i** -- per gestire i cgroup  
**mkdir /sys/fs/cgroup/cage**  -- creiamo il cgroup chiamato 'cage'   
**echo 10 /sys/fs/cgroup/cage/pids.max** -- configuriamo cage x massimo 10 PID allocabili
   
2a shell:  
**echo $$** -- variabile speciale di bash che contiene il PID del processo corrente  

1a shell:  
**echo $$TERMPID > /sys/fs/cgroup/cage/cgroup.procs** -- ingabbiamo il 1o terminale e figli

3a shell:  
**watch -n .3 -t cat /sys/fs/cgroup/cage/pids.current** -- rimaniamo in osservazione sui PID allocati

2a shell:  
**`:() { :|:& };:`** -- lanciamo sta fork bomb

A questo punto sul terzo terminale vedremo il numero di PIDs allocati salire al limite
e sul terminale che ha lanciato la fork bomb, vedremo i messaggi di errore "Resource temporarily unavailable"

![un paio di finestre di tmux sullo scenario descritto](/posts/images/fork_bomb.png "fork bomb")

Quando siamo soddisfatti, possiamo lanciare `echo 1 > /sys/fs/cgroup/cage/cgroup.kill`
dal secondo terminale per terminare il tutto.

Se non limitate i PIDs allocabili da cgroup, potrete veder salire i processi
forkati fino a (in base al vostro sistema) trovare un limite.
Il peggio che può succedervi è che dovete riavviare la macchina.
Questa command line fa parte della serie di command line pericolose su Linux,
molto meno letale di **rm -rfv /*** (non provatela).