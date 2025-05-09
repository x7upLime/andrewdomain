---
title: "Why the fail/rescue mechanism is dangerous - Ansible"
date: 2024-09-13T10:44:48+02:00
draft: true
---

Use case:  
dobbiamo implementare uno switch case. Cosa non presente di default su Ansible.
Ad esempio, per selezionare quale tipo di plugin configurare in base a dei dati parsati.

Se usiamo fail/rescue come meccanismo,
il rescue viene triggerato anche da fallimenti normali come
ad esempio un fallimento dovuto al parsing tramite filtri,
come community.general.json_query, che necessita del modulo python jmespath.

Se lo testate localmente dove avete installato jmespath
e poi lo spostate su un AWX dove non lo avete,
fate un gran casino.

I rescue sono triggerati anche da errori del genere.

# Utilizzare meta: end_play
Una tecnica alternativa potrebbe essere quella di utilizzare
un task che parsa i dati per decidere quale plugin configurare,
una serie di task che settano dei fact a true,
poi i singoli blocchi con include_tasks se il fact è settato true (assieme al filtro default(False),
al cui termine troviamo un task meta: end_play

Decisamente più solido.