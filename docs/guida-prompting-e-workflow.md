# Guida al prompting e all'impostazione di un workflow

Distillato in italiano della guida ufficiale Anthropic ([Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)) e dell'esperienza fatta con il plugin `phased-workflow`. Destinatari: chi lavora con Claude tutti i giorni e vuole interazioni più efficaci — e meno costose.

---

## 0. Prima del prompt

La guida ufficiale apre con un punto che quasi tutti saltano: **il prompt engineering inizia quando hai già tre cose** —

1. un criterio di successo chiaro ("come riconosco un buon risultato?");
2. un modo empirico di verificarlo (un test, un check, un confronto);
3. una prima bozza di prompt da migliorare.

Se manca il punto 1, nessuna tecnica ti salva: stai chiedendo al modello di indovinare cosa vuoi. È lo stesso principio del campo `Done:` nei piani del plugin — se non sai scrivere il criterio di uscita, la fase non è pronta.

---

## 1. Le regole fondamentali (valide per tutti i modelli)

### Chiaro e diretto — la regola del collega

> Mostra il tuo prompt a un collega che non conosce il task e chiedigli di eseguirlo. Se lui sarebbe confuso, Claude lo sarà.

Claude va trattato come un collega brillante ma **appena assunto**: non conosce le tue norme, le tue convenzioni, i tuoi sottintesi. Più precisamente spieghi cosa vuoi, migliore è il risultato. Se vuoi che "faccia di più" (più feature, più cura, più completezza), **chiedilo esplicitamente** — non contare sul fatto che lo inferisca.

- Meno efficace: *"Crea una dashboard di analytics"*
- Più efficace: *"Crea una dashboard di analytics. Includi tutte le feature e interazioni rilevanti. Vai oltre le basi: implementazione completa."*

### Dai il perché, non solo il cosa

Il modello generalizza dalla motivazione. Un vincolo nudo viene applicato meccanicamente (o dimenticato); un vincolo motivato viene applicato con giudizio.

- Meno efficace: *"MAI usare i puntini di sospensione"*
- Più efficace: *"La risposta verrà letta da un motore text-to-speech, quindi niente puntini di sospensione: non saprebbe pronunciarli."*

Vale anche per i task: *"Sto lavorando a X per Y, gli serve Z. Con questo in mente: [richiesta]"* rende ogni scelta intermedia più allineata.

### Esempi > descrizioni

3–5 esempi ben scelti (few-shot) sono il modo più affidabile di controllare formato, tono e struttura. Devono essere **rilevanti** (simili al caso reale), **diversi** (coprire i casi limite), **delimitati** (dentro tag `<example>`). Un esempio positivo di ciò che vuoi batte dieci istruzioni su ciò che non vuoi.

### Struttura con tag XML

Quando il prompt mescola istruzioni, contesto, esempi e input variabili, delimita ogni parte con un tag (`<instructions>`, `<context>`, `<input>`). Elimina l'ambiguità su "questo è un ordine o un dato?".

### Documenti lunghi in alto, domanda in fondo

Con input oltre ~20k token: **prima i documenti, poi la domanda**. Nei test la domanda in fondo migliora la qualità fino al 30%. Per compiti su documenti lunghi, chiedi prima le **citazioni pertinenti** (in `<quotes>`) e poi l'elaborazione: costringe il modello ad ancorarsi al testo.

### Dì cosa fare, non cosa non fare

- Meno efficace: *"Non usare markdown"*
- Più efficace: *"Scrivi in prosa fluida, paragrafi completi"*

### Azione esplicita, non allusa

*"Puoi suggerirmi delle modifiche?"* produce suggerimenti. *"Modifica questa funzione per migliorare le prestazioni"* produce modifiche. I modelli recenti seguono le istruzioni **alla lettera**: se vuoi l'azione, ordina l'azione.

---

## 2. Token e verbosità — dove si spreca davvero

Questa è la parte che ha motivato la revisione 5.3.0 del plugin.

### La narrazione agentica è spesa pura

In una sessione autonoma (`claude -p`, un run notturno, un subagent) **nessuno legge la cronaca in tempo reale**. Ogni "Ora leggo il file X…", "Procedo con…", riepilogo intermedio è token di output pagato senza lettore. La contromisura è una riga di system prompt:

> *Default to silence between tool calls. Only write text when you find something, change direction, or hit a blocker — one sentence each. When done: one or two sentences on the outcome.*

Nel plugin questa riga viene ora iniettata automaticamente dal launcher (`--append-system-prompt`) in ogni sotto-sessione. Il principio generale: **calibra la verbosità sul lettore reale**. Umano che guarda → aggiornamenti utili; log → silenzio.

### Le tue regole di stile stanno quasi sempre nel posto sbagliato

Il gemello interattivo del problema precedente: le risposte *a te* troppo lunghe, che rispondono a domande che non hai fatto e si chiudono con una scelta da prendere. Il costo non sono i token del modello, sono **i tuoi giri**: ogni risposta che non chiude ti costa un altro turno per chiedere la stessa cosa in modo più stretto.

Quasi tutti scrivono la contromisura in `CLAUDE.md`. È il posto più debole dei tre: tecnicamente è un messaggio utente inserito dopo il system prompt, e nelle conversazioni lunghe viene sepolto. Su un'issue di Claude Code lo si legge senza giri di parole:

> *The narration form appears regardless of `CLAUDE.md` instructions asking for terse output. `CLAUDE.md` helps but does not fully eliminate the pattern.*

| Dove | Come agisce | Tenuta |
|---|---|---|
| CLAUDE.md | Messaggio utente dopo il system prompt | Debole: aiuta, non elimina — si diluisce col crescere della conversazione |
| Output style | Modifica il **system prompt**, e Claude Code re-inietta promemoria durante la conversazione | La più solida documentata. È qui che vanno messe |
| Hook `UserPromptSubmit` | Re-inietta la regola a ogni turno come system-reminder | In teoria la più forte, in pratica ha bug aperti (accumulo di contesto, non iniettato in VSCode) |

Quindi: un file in `~/.claude/output-styles/<nome>.md`, attivato con `/output-style`, e `keep-coding-instructions: true` nel frontmatter per non perdere il comportamento di coding. Le regole di stile **escono** da `CLAUDE.md`, che resta per le regole di dominio (git, convenzioni di codice, gate di approvazione).

Cosa scriverci, formulato **al positivo** — Anthropic è esplicita che gli esempi di ciò che vuoi rendono più delle proibizioni:

- **Consegna lo scope chiesto.** Una domanda su *cosa è* una cosa riceve la descrizione di quella cosa: consigli di integrazione, confronti con le alternative e prossimi passi sono domande separate, che si consegnano quando vengono fatte. È la contromisura documentata da Anthropic per Opus 5, di cui scrivono che *"can expand the scope of a task, adding steps that weren't requested"*.
- **Esito in prima riga.** Chi si ferma dopo una riga ha già la risposta.
- **Le spiegazioni sono riassunti, salvo richiesta.** Testuale dalla guida: *"When asked to explain something, give a high-level summary unless an in-depth explanation is specifically requested."*
- **La risposta finisce dove finisce.** L'ultima riga è parte della risposta, non un invito. Se resta del lavoro aperto, si enuncia piatto — *"resta da fare X"* — così chi legge legge un fatto e decide con i suoi tempi, invece di ricevere un compito.
- **Un termine nuovo si definisce in mezza riga** alla prima occorrenza, e si preferisce il vocabolario di chi legge a quello della fonte.
- **Ambiguità vera → una domanda da una riga**, invece di rispondere a entrambe le letture. È lì che il risparmio è grosso: una riga contro sessanta.

Nota che l'`effort` non è la leva: alzarlo o abbassarlo non accorcia in modo affidabile l'output visibile. Anthropic suggerisce anche un promemoria corto a fine prompt, tipo `<tone_preference>Keep outputs reasonably concise.</tone_preference>`.

Nel plugin l'aggiornamento 5.4.0 arriva con uno stile di riferimento (`asciutto`) da copiare e adattare, e con `/grill` — la disciplina gemella sul *chiedere*: una domanda per volta, con la risposta consigliata, i fatti cercati e non chiesti.

### L'effort è la leva costo/qualità, ma non quella della verbosità

`effort` (low/medium/high/xhigh/max) governa quanto il modello pensa ed esplora. Regole pratiche:

- **Parti basso e sali solo per una ragione.** Un task ben specificato è dove l'effort alto rende meno: viene speso a ri-esplorare e ri-verificare decisioni già prese. `low`/`medium` sui modelli recenti rendono molto più di quanto ci si aspetti.
- **`max` quasi mai**: tende all'overthinking, rendimenti decrescenti.
- Su Opus 5 l'effort **non** accorcia in modo affidabile l'output visibile: la verbosità si governa col prompt, non col parametro.

### Non chiedere di "ricontrollare il lavoro" (inversione di una vecchia best practice)

"Chiedi al modello di auto-verificarsi" era un consiglio standard. Sui modelli recenti (Opus 5 in particolare) è **controproducente**: si verificano già da soli, e l'istruzione esplicita produce over-verification — passaggi extra, token, latenza, zero qualità in più. Se hai prompt storici con *"double-check your answer"*, *"verify before responding"*: **cancellali**, non riscriverli.

### De-prescrivere: obiettivo e vincoli, non passi

Prompt scritti per modelli vecchi sono spesso troppo prescrittivi per quelli nuovi e ne **riducono** la qualità. Preferisci enunciare l'obiettivo e i vincoli all'enumerare i passi. Stesso discorso per il linguaggio aggressivo: *"CRITICAL: you MUST use this tool"* oggi produce overtriggering — basta *"Use this tool when…"*. E *"if in doubt, use X"* va proprio eliminato.

### Ancorare le affermazioni di progresso

Nei run lunghi, chiedi che ogni claim di avanzamento sia verificabile:

> *Before reporting progress, audit each claim against a tool result from this session. If something is not yet verified, say so explicitly.*

Nel plugin questo vive nel gate sul `Done:` (rieseguito letteralmente prima di chiudere la fase) e nello steering fable.

---

## 3. Le personalità dei modelli (in breve)

Ogni modello ha derive note; una riga di prompt le smorza. È il motivo per cui la scelta del modello va fatta **in pianificazione**, quando sai che tipo di lavoro è ogni fase.

| Modello | Punto di forza | Deriva nota | Contromisura |
|---|---|---|---|
| **Opus** | Default per quasi tutto; agentico e coding | Scope creep, over-verification, delega facile ai subagent, output lungo | Perimetro esplicito, niente istruzioni di verifica, tetto ai subagent, istruzione di concisione |
| **Sonnet** | Veloce ed economico sul ben specificato | Segue **alla lettera**: un buco di specifica → design inventato | Solo lavoro meccanico con spec completa; un gap deve fermare, non far improvvisare |
| **Fable** | I problemi davvero difficili: architettura, debugging ostico, design senza pattern | Overplanning, ri-derivare decisioni già prese; turni lunghi | *"When you have enough information to act, act"*; decisioni del piano dichiarate chiuse |
| **Haiku** | Classificazioni, task semplici e veloci | Capacità limitata | Non usarlo dove serve giudizio |

Regola del plugin, generalizzabile: **in dubbio → opus**. Una fase sonnet fallita costa una riparazione fable: il risparmio si fa sulla specifica, non sulla scelta ottimistica del modello.

---

## 4. Impostare un workflow

Qui prompting e processo si incontrano. I principi valgono con o senza il plugin; tra parentesi il pezzo del plugin che li incarna.

### Specifica completa upfront, non a goccia

La guida ufficiale è netta: task, intento e vincoli **tutti nel primo turno** massimizzano autonomia e intelligenza; le richieste ambigue rivelate progressivamente su più turni riducono efficienza e a volte qualità. Il modello ragiona (e spende) dopo ogni turno umano: dieci turni di chiarimento sono dieci ripartenze. (Nel plugin: la conversazione di `/write-workflow` esiste proprio per condensare tutto nel piano, una volta.)

### Le decisioni si prendono in pianificazione

Naming, librerie, firme, forme di API, trade-off: tutto ciò che richiede il giudizio umano va deciso **prima** dell'esecuzione e scritto nel piano. Una fase con "decidere poi" non è pronta. Perché: in esecuzione la domanda o blocca il run (autonomo) o interrompe il flusso (interattivo) — e un modello senza risposta inventa. (Nel plugin: campo `Decisions:`, domande batchate in pianificazione.)

### Ogni unità di lavoro ha un'uscita misurabile

*"Tests pass"*, *"il file X esiste con le sezioni Y"*, *"flake8 zero errori sui file toccati"* — rieseguibile da chiunque, macchina inclusa. Mai *"looks good"*. Il criterio misurabile è ciò che permette a un loop autonomo di fermarsi da solo e a te di fidarti del risultato senza rileggere tutto. (Nel plugin: `Done:` come exit condition letterale, ri-verificata da un valutatore indipendente sotto `/goal`.)

### Dai un pattern da copiare

Per codice non banale, indica 1–2 esempi esistenti nel repo da copia-adattare (`Pattern:`). È la forma più densa di prompt che esista: un file reale comunica convenzioni, stile e API più di qualunque descrizione — e costa zero token di spiegazione. Niente di comparabile → dichiaralo (`new-pattern`): è un rischio da conoscere, non da nascondere.

### Interattivo o autonomo? Decidilo, non subirlo

La domanda giusta è: **il successo si misura o si riconosce a vista?**

- *"Lo riconosco quando lo vedo"* (UI, lavoro visuale/dichiarativo, UX) → **interattivo**: un'iterazione per fase con occhio umano; le fasi si chiudono dove esiste qualcosa di guardabile.
- Misurabile (refactor, migrazioni, avvio progetto ben specificato) → **autonomo**: fasi piccole (~una concern, `Done:` rieseguibile), run non presidiato, checkpoint umano alla fine.

Forzare un task esplorativo nel modo autonomo è il modo più costoso di scoprire che serviva una conversazione. (Nel plugin: il fork di Step 2 in `/write-workflow`, con l'honesty check che fa marcia indietro quando sente attrito.)

### Contesto fresco batte contesto lungo

Ogni fase in una sessione nuova, con **stato su file** (il piano, le note, git) invece che in chat: i modelli recenti sono ottimi a ricostruire lo stato dal filesystem, e un contesto corto e pertinente rende più di uno lungo e sporco — oltre a costare meno. Git è memoria gratuita: un commit per fase = checkpoint, cronologia, attribuzione delle regressioni. (Nel plugin: una chat per fase, un commit per fase, `> Files:` per attribuire i guasti.)

### Checkpoint umani ai confini giusti

Non dentro le fasi (lì il loop si auto-corregge), ma **tra i blocchi di lavoro**: a fine run, prima del merge, tra un macro e il successivo. È dove il giudizio umano rende di più per minuto speso. (Nel plugin: `/finalize-workflow`, `review.md` per i finding che meritano un umano, `verify.md` per ciò che solo un umano può esercitare, il confine tra macro-fasi deliberatamente manuale.)

---

## 5. Anti-pattern — checklist rapida

- ❌ Prompt senza criterio di successo ("fammi qualcosa di carino")
- ❌ Contesto rivelato a goccia su dieci turni
- ❌ *"CRITICAL: YOU MUST…"*, *"if in doubt, use X"* (overtriggering sui modelli recenti)
- ❌ *"Double-check your answer"* su Opus 5 (over-verification: cancellare, non riscrivere)
- ❌ Vincoli senza motivazione (il modello non può generalizzare)
- ❌ Dire cosa NON fare invece di cosa fare
- ❌ Effort `max` di default "per sicurezza"
- ❌ Prompt passo-passo dettagliati dove bastano obiettivo e vincoli
- ❌ Modello economico su lavoro sotto-specificato (il fallimento costa più del risparmio)
- ❌ Decisioni di design lasciate all'esecuzione
- ❌ "Done" non misurabile (*"looks good"*, *"should work"*)
- ❌ Stile e verbosità ripetuti in ogni fase del piano (una volta, nel posto giusto — o mai, se il launcher li inietta)
- ❌ Regole di stile scritte in `CLAUDE.md` e mai passate a un output style (si diluiscono, poi si ri-chiede la stessa cosa a mano)

---

## Riferimenti

- [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) — il riferimento vivo, con le pagine per-modello (Fable 5, Opus 5, Sonnet 5, Opus 4.8)
- [Prompt engineering overview](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/overview) — quando il prompt engineering è la soluzione giusta (e quando no)
- [Effort](https://platform.claude.com/docs/en/build-with-claude/effort) e [Adaptive thinking](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking) — le leve costo/qualità
- Questo repo: `plugins/phased-workflow/` — l'implementazione operativa dei principi della sezione 4
