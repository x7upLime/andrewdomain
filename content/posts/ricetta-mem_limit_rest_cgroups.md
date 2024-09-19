---
title: "Ricetta: limite di memoria tramite cgroups"
date: 2024-09-19T11:39:50+02:00
draft: false
description: |
  Un breve tutorial che mostra come scrivere una mock REST API da confinare all'interno
  di un cgroup, rispetto alla memoria. Creando le condizioni per osservare quello che accade vicino al limite.
tags:
 - sys
 - cgroup
 - golang
 - memory
---

Mostreremo come confinare un'applicazione tramite cgroup rispetto alla memoria,
creando le condizioni di osservare quello che accade vicino "al limite",
senza andare ad intaccare le risorse del nostro sistema operativo.

## ingredienti

 + un go compiler (*dnf install go* su Fedora)
 + una shell (nella ricetta userò la varietà *bash*)
 + un kernel Linux ad una versione recente
 + privilegi di root sul sistema

## Procedura
Ad alto livello:   
Necessiteremo di un applicativo da confinare,    
ci occuperemo del setup dei cgroup sul nostro sistema Linux,    
terremo monitorata la situazione per vedere gli effetti sul nostro applicativo.

### Cuciniamo l'applicativo
Nel contesto della High Availability, adottiamo una serie di pratiche per mitigare gli effetti degli
errori più comuni a cui le applicazioni di una certa complessità sono generalmente soggette.

Trattandosi questa di una ricettina veloce da fare quando riceviamo gli ospiti dell'ultimo minuto,
non andiamo ad appesantire l'evento (e le nostre risorse di sistema) con un vero e proprio applicativo di questo calibro,
andiamo piuttosto a crearne uno che simula alcune categorie di problemi riscontrati più di frequente.

La scelta di Go come linguaggio e runtime per l'applicativo è del tutto arbitraria, ed in questo caso una
mia preferenza personale, qualsiasi altro linguaggio di programmazione generico andrà bene.

Utilizziamo il framework go-gin per generare lo scheletro della nostra REST API,
attorno al quale andiamo ad incastonare i diversi endpoint che ci interessano:

  + **/ping** - *Vogliamo vedere se l'applicativo funziona*
  + **/generate-load/memory** - *Vogliamo generare del carico artificiale sulla memoria*

Portiamo il nostro interesse sulla funzione *main*, ovvero da dove la logica
della nostra applicazione prende il controllo del flusso di esecuzione (cerca: "**func main(**" )   
La logica viene spiegata sotto al sorgente.
```go main.go
package main

import (
	"log"
	"math/rand"

	"github.com/gin-gonic/gin"
)

var mem [][]byte

const bufSize = 20*1024*1024
func assertBufferOk() []byte {
	buf := make([]byte, bufSize)
	
	if buf == nil {
		log.Fatal("memory alloc call returned nil buffer")
	} else if len(buf) != bufSize {
		log.Fatal("memory alloc call returnet different buffer size")
	}

	return buf
}


func main() {
	r := gin.Default()

	r.GET("/ping", func(c *gin.Context){
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})

	r.GET("/generate-load/memory", func(c *gin.Context){
		buf := assertBufferOk()

		for i := range buf {
			buf[i] = byte(rand.Intn(256))
		}

		mem = append(mem, buf)
		
		c.Status(200)
	})
	
	err := r.Run("localhost:8080")
	if err != nil {
		log.Fatal(err)
	}
}

```

L'applicativo si basa sul framework gin, che includiamo in main tramite la riga *r := gin.Default()*,
che corrediamo di una logica abbastanza frettolosa: non controlliamo errori o altro.

Ciascun endpoint viene creato tramite r.GET(), che prende come argomenti l'endpoint della REST API ed una funzione
con cui gestire la richiesta, che come unico argomento supporta il meccanismo di gestionde delle richieste di gin.   
Creiamo tale funzione tramite la definzione di una funzione anonima.

**/ping** è molto semplice da implementare. Ritorniamo una struttura JSON dove message: pong.
```go
	r.GET("/ping", func(c *gin.Context){
		c.JSON(200, gin.H{
			"message": "pong",
		})
	})
```

**/generate-load/memory** dovrà generare del carico artificiale sulla memoria, che potrebbe rappresentare
una leak oppure una cattiva gestione delle risorse.

La chiamata **assertBufferOk()** chiede al kernel 20Mi di memoria, controlla di ricevere esattamente
quello che ha chiesto, fa fallire l'intero programma se questo non accade.   

Coloriamo il buffer all'interno del `for i := range buf {}` loop per evitare che il runtime di go
vada a riciclarci la memoria.

Il buffer ritornato viene appeso alla variabile globale che contiene la lista di buffer richiesti (per
evitare che la memoria possa essere pulita dal garbage collector di go)
```go
	r.GET("/generate-load/memory", func(c *gin.Context){
		buf := assertBufferOk()

		for i := range buf {
			buf[i] = byte(rand.Intn(256))
		}
		
		mem = append(mem, buf)
		
		c.Status(200)
	})
```

Il tutto verrà servito sulla :8080 di localhost:
```go
	err := r.Run("localhost:8080")
	if err != nil {
		log.Fatal(err)
	}
```

### Impiattamento
Creiamo una folder per il progetto: `mkdir ./mem_limit && cd Esc+.`   
Generiamo la struttura del modulo go, nella nuova folder: `go mod init`   
Depositiamo il contenuto del sorgente sopra in un file `main.go` della nuova directory.

Apriamo due sessioni di una shell a piacere, ci posizioniamo nella directory del progetto appena creata.   
Nella prima shell lanciamo il comando `go run .`   
La seconda shell la utilizzeremo per interagire col nostro applicativo tramite curl.

Il piatto dovrebbe avere un aspetto simile a questo
![un paio di finestre di tmux sullo scenario descritto](/posts/images/gorest_1-curl.png "REST api e curl")

### Mise en place
Andiamo a creare la struttura del nuovo cgroup che andiamo ad utilizzare per questo tutorial.

Nel secondo terminale (o un terzo o a discrezione del maitre di sala), scaliamo verso l'utenza di root
secondo il meccanismo che preferiamo, personalmente mi sono abituato a `sudo -i`

terminale che controlla:   
**mkdir /sys/fs/cgroup/cage** - per creare il cgroup    
**echo 100000000 > /sys/fs/cgroup/cage/memory.max** - per settare un limite di 100M sulla memoria del cgroup    
**echo 0 > /sys/fs/cgroup/cage/memory.swap.max** - per prevenire lo swapping all'interno del cgroup

terminale controllato (dove gira la nostra app):   
**echo $$** - prendiamo il riferimento al PID di questa shell

terminale che controlla:   
**echo <PID> > /sys/fs/cgroup/cage/cgroup.procs** - per confinare la shell (e figli) nel cgroup   

terminale controllato (dove gira la nostra app):   
**cat /proc/self/cgroup** - per controllare di far parte del cgroup corretto

A questo punto la mise en place dovrebbe avere un aspetto simile al seguente:
![un paio di finestre di tmux sullo scenario descritto](/posts/images/gorest_1-cgroup-setup.png "setup del cgroup")


### Servizio
A questo punto la shell confinata nel cgroup deve lanciare l'applicativo con `go run .`  
Occorre avere anche una shell per lanciare le curl ed una shell che osserva il consumo di memoria del cgroup.

nel terminale che osserva:   
**watch -n .3 -t "cat /sys/fs/cgroup/cage/memory.current | awk '{print \$1/(1024*1024)}'"**

Un paio di curl faranno straripare il livello di memoria rispetto al limite prefissato,  
ed il nostro applicativo verrà oomkillato.
![un paio di finestre di tmux sullo scenario descritto](/posts/images/gorest_1-oomkilled.png "rest api killed")