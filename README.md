# Claude Usage

Widget do macOS lišty se spotřebou Claude Code. V liště ukazuje procenta session
a weekly limitu, po rozkliknutí denní graf, tokeny za 7 / 30 dní i celkem a přepočet
na cenu Claude API.

![Panel](docs/menu.png)

## Instalace

```bash
git clone https://github.com/LiberaFatum/macOS-Claude-Code-usage-widget.git
cd macOS-Claude-Code-usage-widget
./install.sh
```

Přeloží se, nakopíruje do `/Applications/Claude Usage.app` a spustí. Potřebuje macOS 13+
a Command Line Tools (`xcode-select --install`), Xcode ne. Font [Monocraft](https://github.com/IdreesInc/Monocraft)
je volitelný, bez něj se použije systémový monospace.

Spouštění po restartu zapneš v menu: **Nastavení > Spouštět po přihlášení**.

## Odkud jsou data

Vše se čte z lokálních souborů, které si píše sám Claude Code. Aplikace nikam nevolá
a nesahá na klíče ani na Keychain.

| Soubor | Co z něj bere |
| --- | --- |
| `~/.claude.json`, klíč `cachedUsageUtilization` | procenta session a weekly limitu, časy resetu |
| `~/.claude/stats-cache.json` | tokeny po dnech a modelech, celkové součty |

`cachedUsageUtilization` je cache, kterou přepisuje Claude Code při startu a při příkazu
`/usage`. Widget hlídá čas změny souboru a načte ho hned, jak se přepíše, ale čerstvější
než cache sám o sobě nebude. Hlavička panelu proto píše zdroj a stáří údaje.

`stats-cache.json` se přepočítává po dnech, graf tak většinou končí včerejškem.

## Živé čtení limitů

**Nastavení > Číst limity živě z API** obejde cache a zavolá `https://api.anthropic.com/api/oauth/usage`,
tedy stejný endpoint jako Claude Code. Token se hledá v `~/.claude/.credentials.json` a pak
v Keychainu, načte se jednou za běh aplikace a drží se jen v paměti. První čtení Keychainu
vyvolá systémový dialog, potvrď **Vždy povolit**.

Endpoint svůj limit četnosti v hlavičkách nehlásí, odstup mezi dotazy se proto ladí za běhu:
startuje na minutě, po HTTP 429 se zdvojnásobí až k patnácti minutám a po každém úspěchu
klesá zpět k minutě. Ověřit ho jde i z terminálu, ale pozor, ukusuje ze stejného limitu:

```bash
"/Applications/Claude Usage.app/Contents/MacOS/ClaudeUsage" --test-api
```

## Přepočet na API

Ceny podle [oficiálního ceníku](https://platform.claude.com/docs/en/about-claude/pricing),
zvlášť input, output, cache read i cache write, per model. Číslo "celkem" je přesné.
Za 7 a 30 dní jde o odhad: denní data znají jen součet tokenů na model, rozpad na typy
se dopočítá z celkového poměru téhož modelu.

## Nastavení

V liště buď session, weekly, obojí, nebo vyšší z obou. Dál rozsah grafu (14 / 30 / 60 dní),
ikona v liště, živé čtení z API a spouštění po přihlášení.

Soubory se čtou jen když se změní čas jejich úpravy, takže widget na pozadí nic nedělá.

## Odinstalace

```bash
./uninstall.sh
```

Smaže aplikaci, login item i uložené předvolby.

## Licence

MIT
