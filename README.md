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

**Proč jsou limity pozadu:** `cachedUsageUtilization` je cache, kterou obnovuje Claude Code
zhruba jednou za 5 minut, a jen když běží. Zkrácení intervalu v nastavení proto nepomůže,
čte se pořád stejně starý údaj. Widget navíc sleduje čas změny souboru a načte ho hned,
jak se přepíše. Panel proto v pravém horním rohu píše stáří dat, nad 15 minut oranžově.

`stats-cache.json` se přepočítává po dnech, graf tak většinou končí včerejškem.

## Přepočet na API

Ceny podle [oficiálního ceníku](https://platform.claude.com/docs/en/about-claude/pricing),
zvlášť input, output, cache read i cache write, per model. Číslo "celkem" je přesné.
Za 7 a 30 dní jde o odhad: denní data znají jen součet tokenů na model, rozpad na typy
se dopočítá z celkového poměru téhož modelu.

## Nastavení

V liště buď session, weekly, obojí, nebo vyšší z obou. Dál interval načítání, rozsah
grafu (14 / 30 / 60 dní), ikona v liště a spouštění po přihlášení.

## Odinstalace

```bash
./uninstall.sh
```

Smaže aplikaci, login item i uložené předvolby.

## Licence

MIT
