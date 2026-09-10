# Claude Usage

Widget do macOS lišty se spotřebou Claude Code. V liště procenta session a weekly
limitu, po rozkliknutí denní graf, tokeny za 7 / 30 dní i celkem a přepočet na cenu
Claude API.

*macOS menu bar widget showing Claude Code rate limits and token usage. Czech UI.
Install: `git clone`, then `./install.sh`. Needs macOS 13+ and Xcode Command Line
Tools (`xcode-select --install`). Everything else the script checks for you.*

![Lišta](docs/menubar.png)

![Panel](docs/menu.png)

## Instalace

Potřebuješ macOS 13 nebo novější a Xcode Command Line Tools. Jestli je nemáš,
instalace ti to řekne a poradí příkaz. Xcode samotné potřeba není.

**Jedním příkazem:**

```bash
curl -fsSL https://raw.githubusercontent.com/LiberaFatum/macOS-Claude-Code-usage-widget/main/Tools/bootstrap.sh | bash
```

**Nebo klasicky, když chceš vidět, co stahuješ:**

```bash
git clone https://github.com/LiberaFatum/macOS-Claude-Code-usage-widget.git
cd macOS-Claude-Code-usage-widget
./install.sh
```

**Nebo bez terminálu:** po naklonování dvakrát klikni na `Install.command`.

Překlad trvá zhruba minutu. Aplikace se nainstaluje do `/Applications/Claude Usage.app`.

### Jak poznáš, že je hotovo

V pravé části horní lišty přibude oranžový panáček a vedle něj procenta, například
`12 % s | 34 % w`. Z terminálu to ověříš takhle:

```bash
pgrep -fl "Claude Usage.app"
```

Spouštění po restartu zapneš v menu widgetu: **Nastavení > Spouštět po přihlášení**.

### Když něco nevyjde

| Co vidíš | Co s tím |
| --- | --- |
| `Chybí Xcode Command Line Tools` | Spusť `xcode-select --install`, v systémovém okně klikni na Instalovat, počkej a instalaci opakuj. Ten dialog musí odklikat člověk. |
| `xcrun: error: invalid active developer path` | Totéž, nástroje rozbil upgrade systému: `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install` |
| Instalace doběhla, ale v liště nic není | `open "/Applications/Claude Usage.app"`, pak `cat ~/Library/Logs/ClaudeUsage.log` |
| V liště jsou otazníky místo procent | Claude Code na tomhle stroji ještě neběžel, nebo neuložil data. Spusť ho jednou a v jeho sezení napiš `/usage`. |
| macOS tvrdí, že je aplikace poškozená | Stáhl jsi repozitář jako ZIP, který má karanténní příznak. Použij `git clone`, nebo spusť `xattr -dr com.apple.quarantine "/Applications/Claude Usage.app"`. |
| Během instalace vyskočí okno svazku klíčů | Klikni na **Povolit vždy**. Když se dialog vrací i další dny, nastav widgetu vlastní token, viz část o živém čtení. |

Instalace nikdy nehlásí úspěch, pokud widget opravdu neběží. Když skončí chybou,
poslední odstavec výpisu říká, co dělat.

## Odkud jsou data

| Zdroj | Co z něj bere |
| --- | --- |
| `https://api.anthropic.com/api/oauth/usage` | živá procenta limitů, volitelné, viz níže |
| `~/.claude.json`, klíč `cachedUsageUtilization` | tatáž procenta z cache, když živé čtení neběží |
| `~/.claude/stats-cache.json` | tokeny po dnech a modelech, celkové součty |

Statistiky tokenů se čtou vždy jen z lokálního souboru. Soubory se parsují pouze při
změně jejich času úpravy, takže widget na pozadí prakticky nic nedělá.

`cachedUsageUtilization` přepisuje Claude Code při startu a při příkazu `/usage`, mezitím
stárne. Proto to živé čtení.

`stats-cache.json` se přepočítává po dnech, graf tak většinou končí včerejškem.

## Živé čtení limitů

**Nastavení > Číst limity živě z API** volá stejný endpoint jako Claude Code. Token se
hledá v `~/.claude/.credentials.json` a pak v Keychainu, načte se jednou a drží se jen
v paměti. První čtení Keychainu vyvolá systémový dialog, potvrď **Povolit vždy**.

### Proč aplikace potřebuje vlastní podpis

Povolení "Povolit vždy" je navázané na otisk podepsané aplikace. Ad-hoc podpis se mění
při každém překladu, takže by povolení po každé aktualizaci propadlo a systém by si znovu
řekl o heslo. `install.sh` proto nejdřív vytvoří lokální podpisovou identitu
`Claude Usage Local` (`Tools/create-signing-identity.sh`) a podepíše jí aplikaci.
Požadavek podpisu pak zní `identifier "com.liberafatum.claude-usage-widget" and
certificate leaf = H"..."`, tedy nezávisle na obsahu binárky. Certifikát zůstává jen
na tvém stroji. Odstraní ho `uninstall.sh`, nebo ručně:

```bash
security delete-identity -c "Claude Usage Local"
```

Bez identity widget funguje taky, jen se podepíše ad-hoc a dialog se bude vracet.
Když instalace běží bez terminálu, třeba z AI agenta, tenhle krok se přeskočí,
protože by se zasekl na dialogu. Doplníš ho kdykoli:

```bash
./Tools/create-signing-identity.sh && ./install.sh
```

### Vlastní token, když se systém pořád ptá na heslo

Claude Code při obnově svého tokenu položku ve svazku klíčů přepíše, čímž se vynuluje
seznam povolených aplikací. Povolení "Povolit vždy" tak propadne a dialog se vrací,
typicky jednou nebo dvakrát denně. Řešením je dát widgetu vlastní dlouhodobý token,
který si uloží do své vlastní položky. U položky, kterou aplikace sama vytvořila,
se systém neptá, a Claude Code do ní nesahá.

V opravdovém okně Terminálu, protože příkaz otevírá prohlížeč:

```bash
claude setup-token
```

Vypsaný token předej widgetu, třeba ze schránky:

```bash
pbpaste | "/Applications/Claude Usage.app/Contents/MacOS/ClaudeUsage" --set-token
```

Jde i ze souboru, `--set-token --file ~/token.txt`, nebo napsáním, když příkaz spustíš
bez roury. Ověření musí psát `zdroj tokenu: vlastní token`:

```bash
"/Applications/Claude Usage.app/Contents/MacOS/ClaudeUsage" --test-api
```

Zpátky k tokenu Claude Code se vrátíš příkazem `--clear-token`.

### Platnost tokenu

Token má omezenou platnost a obnovuje ho jen Claude Code. Widget si proto čte `expiresAt`
a po vypršení už na API nesahá, jen napíše do panelu, že se čeká na obnovu. Do Keychainu
sáhne nejvýš jednou za 15 minut, protože každé čtení může znovu vyvolat dialog s heslem.

Endpoint svůj limit četnosti nehlásí užitečně (na 429 posílá `retry-after: 0`), odstup
mezi dotazy se proto ladí za běhu: startuje na pěti minutách, po HTTP 429 se zdvojnásobí
až k patnácti minutám a po každém úspěchu klesá zpět.

Ověření z terminálu, pozor, ukusuje ze stejného limitu jako běžící widget:

```bash
"/Applications/Claude Usage.app/Contents/MacOS/ClaudeUsage" --test-api
```

Neúspěchy se zapisují do `~/Library/Logs/ClaudeUsage.log` včetně OSStatus z Keychainu.

## Přepočet na API

Ceny podle [oficiálního ceníku](https://platform.claude.com/docs/en/about-claude/pricing),
zvlášť input, output, cache read i cache write, per model. Číslo "celkem" je přesné.
Za 7 a 30 dní jde o odhad: denní data znají jen součet tokenů na model, rozpad na typy
se dopočítá z celkového poměru téhož modelu. Model, který v ceníku chybí, se do součtu
nezapočítá a panel na to oranžově upozorní.

## Nastavení

V liště buď session, weekly, obojí, nebo vyšší z obou, ve tvaru `45 % s | 35 % w`.
Dál rozsah grafu (14 / 30 / 60 dní), ikona v liště, živé čtení z API a spouštění
po přihlášení.

## Odinstalace

```bash
./uninstall.sh
```

Smaže aplikaci, login item, podpisovou identitu i uložené předvolby.

## Licence

MIT
