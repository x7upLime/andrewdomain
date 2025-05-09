---
title: "Ricetta Cpu_limit_rest_cgroups"
date: 2024-09-19T15:01:33+02:00
draft: true
---

**/generate-load/cpu** è anche relativamente facile. Il consumo di cpu dei processi su Linux funziona così:
consumo quanta cpu mi viene data dal kernel; se devo svolgere della computazione ed il kernel mi da tempo sulla cpu,
allora svolgerò la mia computazione.    
Una volta finito la computazione, il mio processo non rappresenta più un carico per la cpu di sistema.   
Per questo motivo scegliamo di svolgere un task, il cui compimento richiede parecchia computazione,
la scelta più ovvia è il calcolo di un checksum su una stringa di bytes.   
La chiamata **assertOpenDevZero()** ritorna un file descriptor per /dev/zero, la nostra
sorgente di stringhe di bytes, su cui computare i checksum.   
Lanciamo quindi una goroutine (una chiamata asincrona ad una funzione) che brucia cpu (**burnCPU()**).  
La funzione è definita come segue, ed ha il preciso scopo di allocare un buffer,
leggere da /dev/zero fino a riempirne il contenuto, e computare un hash sha256 sul contenuto del buffer.
```go
func burnCPU(f *os.File) {

```
La computazione dell'hash sha256 è un calcolo matematicamente complesso, che richiede diversi cicli di cpu.  
Se questa funzione viene chiamata come goroutine, leggerà e computerà hash sul contenuto di /dev/zero, all'infinito.  
Ciascuna chiamata corrisponderà ad una nuova goroutine.
