---
title: "Una solució artesanal per mirar 3Cat des de fora del país"
date: 2025-09-01T15:36:59+03:00
draft: false
description: |
  Un mini tutorial en català per configurar un SOCKS5 proxy i mirar
  Bola de Drac en 3Cat des de fora.
tags:
 - sys
 - català
---

Abans de començar, crec que es un deure explicar per què tot aixó.  
M'agrada pensar que no existeixen limits al que un pot fer, i per aixó moltes vagades em trobo en situacions ximpletes com aquesta,
on he d'aprendre el català abans de final d'any per fer una presentaciò técnica.

3CAT es una plataforma on posen moltes coses en català que em fan sentir còmode per al meu
aprenentatge, però és accessible nomès des de certs països, que no inclouen aquell on em trobo ara mateix.  
Generalment, quan tens una web app que limita el contingut a una zona geogràfica, la primera cosa que penses
és en una VPN. El concepte és situar una màquina en una zona geogràfica, i fer de manera
que el servei vegi aquesta màquina com si fos la teva (el teu ordinador).

Hi ha diverses opcions per fer això.

## Que utilitzar?
He mirat una mica d'opcions pel meu cas:
	+ Vull fer de manera que 3Cat vegi al meu trànsit com si fos provenient d'Espanya
	+ Vull que el trànsit del meu ordinador no estigui influït per això
	+ Vull utilitzar aquest 'spoofing' nomès per als dominis .cat
	
Aquestes sòn les tecnologies que he mirat.

|              | Ease of setup  | for only targeted websites |
|--------------|----------------|----------------------------|
| VPN          | easy           | could be complicated       |
| HTTP PROXY   | less than easy | .pac file --> easy         |
| SOCKS5 PROXY | eazy peazy     | .pac file --> easy         |
|              |                |                            |

Doncs, què cuinem?

+ Una VPN tindria sentit, però generalment es tracta d'una interfície virtual en el teu sistema operatiu, que es comporta com
	una interfìcie normal, i per això, per dirigir nomès el trànsit que vull jo a la VPN, hauria de fer regles de routing en el sistema
+ D'altra banda, WireGuard es un servei de VPN molt fàcil de desplegar.
+ Un sevei de HTTP proxy com el SquidProxy faria exactament el que necessito, però no és gaire immediat de desplegar, 
	i avui moltes web apps utilitzen protocols diferents d'HTTP/HTTPS per al multimedia streaming. No ho sè...
+ Un SOCKS5 admet els protocols basats en TCP i UDP, i ès massa versàtil i fàcil de desplegar.
	
Mitjançant l'SSHD present a la major part de les distribucions basades en Linux, és possible desplegar un servei 
SOCKS5 amb una sola línia d'ordres.

L'elecció recau en SOCKS5.

## Procediment
 1. Posar en marxa un nanode a Espanya
 2. Afegeix-ho al teu fitxer ~/.ssh/config
 3. Verifica que pots fer ssh a la màquina
 4. Crea un servei per l'endpoint local del SOCKS
 5. Afegeix un fitxer PAC perquè només funcioni amb dominis .cat al navegador
 6. Enllaça el navegador
 7. Verifica la connexió
 
### Posar en marxa un nanode a Espanya
És la part més fàcil i l'ùnica que et costa diners.

He d'anar a un servei de hosting barat (en el meu cas Linode) i crear una màquina petita que estigui geolocalitzada a Espanya.

El sistema operatius és indiferent. Gairebé totes les distribucions de Linux tenen un servidor SSHD.

L'important és que posem una clau SSH per fer l'autenticaciò.

![Un nanode a Espanya](/posts/images/nanode_spain.png "un nanode a Espanya")

Fet!

### Afegeix-ho al teu fitxer ~/.ssh/config
No cal tenir resolució DNS ni res.
Tenir la maquina al teu `~/.ssh/config` ja és prou.

El hostname és la teva IP que et dona Linode o el teu proveïdor de hosting, i l'user és el que
configures per autenticar-te a la maquina.

![sockspain](/posts/images/sockspain_sshconfig.png "sockspain")

Fet!

### Verifica que pots fer ssh a la màquina
L'important és que puguis fer SSH a la màquina, basant-te en el fitxer `~/.ssh/config`

En el meu cas: `ssh sockspain`

Entrem, fem un parell de configuracions al vol i sortim.

![sockspain al vol](/posts/images/sockspain_ssh.png "sockspain al vol")

### Crea un servei per l'endpoint local del SOCKS
Tota la lógica que necessitem està en una línia d'ordres del client SSH. Per aixó podem crear un 
fitxer de servei de systemd i posar-lo a `~/.config/systemd/user/sockspain.service`.

El fitxer té més o menys aquesta forma:
```systemd.service ~/.config/systemd/user/sockspain.service
[Unit]
Description=SOCKS5 proxy located in Spain
After=network.target

[Service]
Type=exec
ExecStart=/usr/bin/ssh -N -D 1080 -o ExitOnForwardFailure=yes user123@sockspain

[Install]
WantedBy=multi-user.target
```

On la part important es: `/usr/bin/ssh -N -D 1080 -o ExitOnForwardFailure=yes user123@sockspain` (user123 és un nom d'usuari qualsevol).

Ara només falta llançar les línies d'ordres per carregar a la memòria i activar el nou servei *sockspain*.
```bash
systemctl --user daemon-reload
systemctl --user start sockspain
```

#### Per què un servei local?
Molt bona pregunta!

Teòricament, el navegador es pot connectar a un SOCKS proxy remot, 
però això implicaria tenir un SOCKS proxy remot obert, probablement no autenticat, 
i ja no és una bona idea: en el millor dels casos, tothom podria connectar-se al teu SOCKS proxy.

Una idea millor és tenir un servei local que faci una connexió SSH protegida amb clau privada
i fer passar tot el trànsit per allà, mantenint-lo xifrat

### Afegeix un fitxer PAC perquè només funcioni amb dominis .cat al navegador
Quan un navegador com Firefox et demana un URL per a una configuració automàtica, generalment vol un 
servei web que li proporcioni un fitxer `.pac`.

PAC vol dir "Proxy Auto-Config" i es un altre estàndard que heretem del projecte Netscape dels anys noranta.

Ès bàsicament un JavaScript que el navegador utilitza cada vagada que carrega un URL i filtra els proxies 
basats en el hostname i l'adreça URL.

![firefox proxy config](/posts/images/firefox_pac_config.png "firefox proxy config")

Crearem un altre servei local que exporti el fitxer PAC aquest de la manera més simple i barata possible, a l'adreça: *http://127.0.0.1:1081*
```javascript
function filterByUrl(url, host) {
	 if (shExpMatch(host, "*.cat")) {
	    return  "SOCKS5 127.0.0.1:1080";
	 }

	 return "DIRECT";
}
```

Podriem aixecar un servidor HTTP i fer que exporti el fitxer. Però no vull tenir fitxers solts a la màquina.

Podriem preparar una imatge de contenidor amb un servidor HTTP i el fitxer a dins, 
mantenint només el Containerfile. Però després necessitaríem un podman o alguna cosa similar, i ja és massa hardcore

I si fos un netcat escoltant en un port?

Al netcat li podríem passar el text per una canonada (pipe).
```bash
while true ; do printf 'HTTP/1.1 200 OK\r\nContent-Type: application/x-ns-proxy-autoconfig\r\n\r\nfunction FindProxyForURL(url,host){if(shExpMatch(host,"*.xyz"))return "SOCKS5 127.0.0.1:1080";return "DIRECT";}' | nc -l 127.0.0.1 1081 ; done
```

Funcionaria?
```bash
[andrew@leather-jacket ~]$ curl localhost:1081
function FindProxyForURL(url,host){if(shExpMatch(host,"*.cat"))return "SOCKS5 127.0.0.1:1080";return "DIRECT";}[andrew@leather-jacket ~]$ 
```

Funciona... I si el posem en una service unit, funcionaria?
```systemd.service ~/.config/systemd/user/allcatpac.service
[Unit]
Description=PAC static content server
After=network.target

[Service]
Type=exec
ExecStart=/bin/sh -c 'while true; do { printf "HTTP/1.1 200 OK\\r\\nContent-Type: application/x-ns-proxy-autoconfig\\r\\n\\r\\nfunction FindProxyForURL(url,host){if(shExpMatch(host,\\"*.cat\\"))return \\"SOCKS5 127.0.0.1:1080\\";return \\"DIRECT\\";}"; } | nc -l 127.0.0.1 1081; done'

[Install]
WantedBy=multi-user.target
```

```bash
[andrew@leather-jacket ~]$ curl localhost:1081
function FindProxyForURL(url,host){if(shExpMatch(host,"*.cat"))return "SOCKS5 127.0.0.1:1080";return "DIRECT";}[andrew@leather-jacket ~]$ 
```

Funciona una altra vegada.

```bash
systemctl --user daemon-reload
systemctl --user start allcatpac
```

### Enllaça el navegador
La configuració és la mateixa que abans, ara només tenim el servei de veritat.

Per verificar que la teva IP sigui realment la de la màquina remota, 
pots utilitzar qualsevol servei del tipus whatsmyip.  
Només has de buscar a Google "what is my ip" i clicar en un dels molts resultats.

Jugant una mica amb el servei allcatpac, pots definir el proxy per el domini (e.g.) .io i provar el canvi d’IP.
a (e.g.) https://whatismyipaddress.com/ i https://ipinfo.io/what-is-my-ip, tenint en compte que cal reiniciar 
el navegador i el servei *allcatpac*.

### Ja està

![Bola de Drac](/posts/images/bola_de_drac.png "bola de drac")
