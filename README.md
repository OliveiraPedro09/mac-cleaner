# Faxina

Limpador de disco para macOS que explica o que está apagando.

A diferença para os limpadores comuns não é o que ele remove, é o que ele te conta antes.
Cada alvo do catálogo declara duas coisas: **o que aquele diretório é tecnicamente** e
**o que muda na sua vida se ele sumir**. Se não dá pra escrever a segunda frase com
honestidade, o alvo não entra no catálogo.

App nativo em SwiftUI, sem dependências externas. Nada é enviado para lugar nenhum.

---

## Requisitos

|       |                                                                             |
| ----- | --------------------------------------------------------------------------- |
| macOS | 14.0 (Sonoma) ou superior                                                   |
| Xcode | 16 ou superior —**o Xcode completo, não só as Command Line Tools** |
| Swift | 6.0+ (o pacote usa`swift-tools-version:6.0` e language mode v6)           |

O Xcode completo é necessário porque o build gera um binário universal
(`--arch arm64 --arch x86_64`), o que exige o SDK do macOS que só vem com o Xcode.
Confira com `swift --version`.

## Como rodar

```bash
git clone <url-do-repo>
cd <pasta-do-repo>/Faxina
./build.sh
open build/Faxina.app
```

Só isso. O `build.sh` compila, monta o bundle `.app`, gera o ícone e assina ad-hoc.
Não baixa nada — o projeto não tem dependências.

Para instalar de vez:

```bash
cp -R build/Faxina.app /Applications/
```

### Acesso Total ao Disco

Sem essa permissão o app **funciona, mas mede menos do que existe**: vários diretórios
dentro de `~/Library` são invisíveis para processos sem ela, e a remoção falha com erro
de permissão (o app mostra a dica na própria linha do erro).

Para conceder: **Ajustes do Sistema → Privacidade e Segurança → Acesso Total ao Disco →
`+` → selecione o `Faxina.app`**.

A assinatura ad-hoc do `build.sh` existe justamente para isso: sem ela o macOS trata cada
recompilação como um app diferente e a permissão precisaria ser concedida de novo toda vez.

### Como usar

1. O app varre assim que abre — 40+ alvos em paralelo, a lista vai se preenchendo.
2. A aba **Catálogo** agrupa o que achou em três faixas de risco. Só a faixa verde vem
   pré-selecionada.
3. A aba **Descobertas** é opcional e só de leitura: mede os diretórios de primeiro nível
   da sua home e de `/Applications` e lista tudo acima de 500 MB, marcando o que o catálogo
   já cobre. Serve para achar o que nenhum catálogo fixo acharia.
4. **Revisar e limpar** abre uma folha com o caminho exato de tudo que será removido.
   Nada é apagado sem estar escrito ali.
5. No fim dá para exportar um relatório em Markdown com o antes/depois.

## As três faixas de risco

| Faixa                              | Significado                                                               | Exemplos                                                                |
| ---------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| 🟢**Risco nulo**             | Cache 100% regenerável. Nenhum código, credencial ou config é afetado. | Xcode DerivedData, cache do NPM, cache HTTP do Chrome                   |
| 🟠**Regenerável com custo** | Volta, mas cobra: re-download pela rede ou perda de estado de UI.         | Repositório Maven, modelos do HuggingFace, workspaceStorage do VS Code |
| 🔴**Dados de usuário**      | Conteúdo seu. Só apague sabendo que existe cópia.                      | Disco da VM do Docker (leva volumes junto)                              |

Selecionar qualquer item vermelho obriga a digitar `APAGAR` antes do botão liberar.

---

## Estrutura do código

```
Faxina/
├── build.sh              → compila, monta o .app, gera ícone, assina
├── make-icon.swift       → desenha o ícone em runtime (evita versionar PNGs)
├── Package.swift         → manifesto SPM, sem dependências
└── Sources/Faxina/
    ├── FaxinaApp.swift   → @main, janela única
    ├── AppModel.swift    → estado observável e orquestração
    ├── Model/            → o que existe
    ├── Core/             → como se descobre, mede e remove
    └── Views/            → SwiftUI
```

### Model — o que existe

**[Catalog.swift](Faxina/Sources/Faxina/Model/Catalog.swift)** — o coração do projeto e o único
arquivo que a maioria das contribuições vai tocar. 40+ alvos declarados, agrupados por
ecossistema (Node, JVM, Go, Rust, Xcode, Android, editores, navegadores, apps, sistema).
Cada entrada carrega `what` (função técnica) e `consequence` (impacto prático) — são esses
textos que aparecem na UI.

**[Target.swift](Faxina/Sources/Faxina/Model/Target.swift)** — o tipo de um alvo, e o enum `Source`
que define como seus caminhos são descobertos: `.paths` (literais), `.glob` (padrão com `*`)
ou `.provider` (lógica dedicada). Aqui também vivem `Command`, para alvos que exigem uma
ferramenta externa em vez de `rm`, e as flags `blockingApps` / `requiresAdmin`.

**[Risk.swift](Faxina/Sources/Faxina/Model/Risk.swift)** — as três faixas, com título, descrição,
cor e ícone. A ordem importa: a limpeza sempre executa do mais seguro para o mais arriscado.

### Core — como funciona

**[SafetyGuard.swift](Faxina/Sources/Faxina/Core/SafetyGuard.swift)** — **leia este primeiro se
quer confiar no app.** É a última linha de defesa, e roda duas vezes: na varredura e de
novo imediatamente antes de cada remoção, sobre o caminho já resolvido. Sete regras, e um
caminho precisa passar em todas:

1. absoluto e não é `/`
2. não é raiz de sistema nem a home
3. está dentro da home ou de uma raiz externa explicitamente liberada
4. não é, não contém e não está dentro de nada protegido — `~/.ssh`, `~/.aws`, `~/.config`,
   Keychains, iCloud Drive, `~/Documents`, `~/Desktop`, dotfiles de shell, e mais
5. não está dentro de um repositório git (é onde vive código de verdade)
6. não atravessa ponto de montagem para outro volume
7. o último componente não é symlink — apagar seguiria para fora

Recusa não é silenciosa: cada caminho barrado aparece na UI e no relatório com a regra que
o barrou.

**[Providers.swift](Faxina/Sources/Faxina/Core/Providers.swift)** — resolve os alvos que exigem
decisão em vez de um caminho fixo: "as versões antigas", "os órfãos", "tudo menos o atual".
Cobre Node via nvm (preserva sempre a default e a maior de cada major), simuladores iOS,
DeviceSupport, IDEs JetBrains, Discord e archives do Xcode com mais de 60 dias. Traz uma
`struct Version` própria para ordenar corretamente `26.5 < 26.10`.

**[Scanner.swift](Faxina/Sources/Faxina/Core/Scanner.swift)** — resolve cada alvo em caminhos
concretos, passa pela guarda antes de sequer medir, e emite resultados por `AsyncStream`
com paralelismo limitado a 4 — por isso a lista se preenche progressivamente.

**[Sizer.swift](Faxina/Sources/Faxina/Core/Sizer.swift)** — mede blocos alocados em disco, não
tamanho lógico (a mesma conta que o `du` faz). Cede o processador a cada 8192 arquivos para
manter a UI viva e permitir cancelamento.

**[Cleaner.swift](Faxina/Sources/Faxina/Core/Cleaner.swift)** — executa. Revalida pela guarda,
mede antes, remove, mede depois: o espaço liberado que aparece no relatório é **medido de
fato**, não estimado. Três caminhos de remoção: comando externo (simuladores exigem
`simctl delete`, apagar o diretório corromperia o índice do CoreSimulator), `rm` com
privilégio de admin (só para os wallpapers root-owned do macOS), ou `FileManager` normal.

**[BigDirs.swift](Faxina/Sources/Faxina/Core/BigDirs.swift)** — alimenta a aba Descobertas. Existe
porque catálogo fixo é o ponto cego de todo limpador: numa máquina real os maiores
consumidores são específicos dela.

**Auxiliares** — [Paths.swift](Faxina/Sources/Faxina/Core/Paths.swift) (expansão de `~` e um glob
próprio, sem depender de shell), [Shell.swift](Faxina/Sources/Faxina/Core/Shell.swift) (subprocessos;
lê os pipes antes do `waitUntilExit` para não travar com saída grande),
[DiskInfo.swift](Faxina/Sources/Faxina/Core/DiskInfo.swift) (mede `/System/Volumes/Data`, que é onde
o espaço real está em APFS), [RunningApps.swift](Faxina/Sources/Faxina/Core/RunningApps.swift)
(detecta e encerra apps que bloqueiam um alvo),
[ReportWriter.swift](Faxina/Sources/Faxina/Core/ReportWriter.swift) (relatório Markdown).

### Views

[RootView.swift](Faxina/Sources/Faxina/Views/RootView.swift) monta as duas abas e o rodapé de ação,
e reavalia a cada 3s quais apps bloqueadores estão abertos — os avisos somem sozinhos quando
você fecha o app. [ConfirmSheet.swift](Faxina/Sources/Faxina/Views/ConfirmSheet.swift) é a última
tela antes de qualquer remoção, com caminho por caminho e a confirmação digitada.
[TargetRow.swift](Faxina/Sources/Faxina/Views/TargetRow.swift) é onde `what` e `consequence` viram
texto na tela. As demais: [CatalogView](Faxina/Sources/Faxina/Views/CatalogView.swift),
[DiscoveryView](Faxina/Sources/Faxina/Views/DiscoveryView.swift),
[DiskHeader](Faxina/Sources/Faxina/Views/DiskHeader.swift),
[ResultsView](Faxina/Sources/Faxina/Views/ResultsView.swift).

---

## Adicionando um alvo ao catálogo

Na prática é uma entrada em [Catalog.swift](Faxina/Sources/Faxina/Model/Catalog.swift):

```swift
Target(id: "ferramenta.cache", name: "Cache da Ferramenta", group: "Grupo", risk: .safe,
       what: "O que este diretório é, tecnicamente.",
       consequence: "O que muda na vida de quem apagar.",
       source: .path("~/.ferramenta/cache"),
       blockingApps: ["com.exemplo.ferramenta"])   // opcional
```

Três coisas que valem a pena respeitar:

- **`consequence` não é enfeite.** É a única razão de o app existir. Se você não consegue
  escrever essa linha com honestidade, o alvo não deveria estar no catálogo.
- **A faixa de risco na dúvida é a de cima.** `.safe` é só para o que reconstrói sozinho,
  sem custo perceptível.
- **Se a ferramenta mantém índice próprio, use `Command`** em vez de deixar o app apagar o
  diretório — veja como os simuladores são tratados em `Providers.simulators`.

Caminhos que a guarda recusa não precisam de tratamento especial: eles simplesmente não
aparecem, e a recusa fica registrada no relatório.

## Licença

Copyright © 2026 Pedro Martins de Oliveira.

Distribuído sob a **GNU Affero General Public License v3.0** — veja [LICENSE](LICENSE).

Na prática, para quem só quer usar: baixe, compile, rode, modifique à vontade, sem custo.

Para quem quer **redistribuir ou oferecer como serviço**: a AGPL exige que o código-fonte
completo do que você distribuir — incluindo suas modificações — seja disponibilizado sob
esta mesma licença. A parte "Affero" fecha a brecha do SaaS: rodar uma versão modificada
em servidor, acessível pela rede, também conta como distribuição.

### Licenciamento comercial

Se você quer usar o Faxina, no todo ou em parte, dentro de um produto proprietário — sem
abrir o código do seu produto, como a AGPL exigiria — **existe uma licença comercial
disponível**. Entre em contato para negociar os termos.

📧 pedromartinsoliveira9@gmail.com

### Contribuindo

Ao enviar um pull request, você concede ao autor o direito de licenciar sua contribuição
tanto sob a AGPL-3.0 quanto sob a licença comercial. Isso é o que mantém o modelo duplo
possível — sem isso, cada contribuidor teria poder de veto sobre o licenciamento comercial.
