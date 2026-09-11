# Minitela Linux Compatibility Kit

> Execute o **Minitela Positivo** no Fedora, Arch Linux e Omarchy sem
> redistribuir nem modificar o pacote original do fabricante.

O kit extrai localmente o `.deb` oficial, instala somente os arquivos
necessários e fornece adaptações para as expectativas Debian do aplicativo.

## Escolha sua distribuição

| Sistema | Instalador | Estado |
| --- | --- | --- |
| Fedora | `scripts/fedora/install.sh` | Testado em GNOME/Wayland com SELinux enforcing. |
| Omarchy / Arch Linux | `scripts/arch/install.sh` | Esperado; usa XWayland no Hyprland quando disponível. |
| Outros sistemas RPM | — | Planejado. |

## Instalação

Primeiro, baixe o `.deb` original por uma fonte autorizada. Este repositório
não contém executáveis, recursos, firmware ou qualquer arquivo proprietário
da Positivo.

```bash
git clone https://github.com/eduardoaugustolb/minitela-linux-compat.git
cd minitela-linux-compat
```

### Fedora

```bash
./scripts/fedora/install.sh ~/Downloads/minitela_1.0.20_amd64.deb
```

O instalador exige SELinux ativo (`Enforcing` ou `Permissive`) e valida os
contextos dos diretórios de sistema antes e depois da instalação.

### Omarchy e Arch Linux

```bash
./scripts/arch/install.sh ~/Downloads/minitela_1.0.20_amd64.deb
```

O instalador verifica se a distribuição é Arch ou derivada, instala as
dependências por `pacman` — incluindo `gtkmm3`, necessário ao binário — e
recusa sobrescrever caminhos já existentes ou pertencentes a pacotes.

## Abrir o aplicativo

Abra **Minitela** pelo menu ou execute:

```bash
/usr/local/bin/minitela-show
```

O lançador traz a janela para frente quando o processo já está residente na
bandeja. Em Omarchy/Hyprland, utiliza o backend X11 via XWayland se `DISPLAY`
estiver disponível. Se o processo encerrar antes de criar o socket interno, o
lançador retorna imediatamente e aponta para `/tmp/minitela.log`.

## Manutenção

Use sempre o conjunto de scripts correspondente à instalação criada.

| Ação | Fedora | Arch / Omarchy |
| --- | --- | --- |
| Reparar wrappers e dependências | `sudo ./scripts/fedora/repair.sh` | `sudo ./scripts/arch/repair.sh` |
| Desinstalar | `./scripts/fedora/uninstall.sh` | `./scripts/arch/uninstall.sh` |
| Limpar arquivos de instalação Fedora antiga | `sudo ./scripts/fedora/cleanup-legacy.sh --apply pacote.deb` | — |

Os instaladores mantêm um manifesto de propriedade. A desinstalação recusa
remover itens não rastreados e os fluxos Arch/Fedora não podem operar sobre a
instalação um do outro.

## Estrutura do projeto

```text
scripts/
├── arch/       # instalação, reparo e remoção para Arch/Omarchy
├── common/     # lançador e shims reutilizados por todas as distros
└── fedora/     # instalação, reparo, remoção e migração segura Fedora
tests/
└── static/     # validações de sintaxe e barreiras de segurança
```

## Validar alterações

```bash
./tests/static/installer-safety.sh
```

O teste estático valida sintaxe, manifestos, proteção de caminhos, dependências
Arch e as barreiras SELinux do instalador Fedora. Faça a validação completa em
uma VM ou snapshot, especialmente antes de mudanças no fluxo de instalação.

## Limitações conhecidas

- Transferências de GIF podem apresentar corrupção ocasional; teste antes de
  usar conteúdos importantes.
- O aplicativo usa GTK3 e APIs de bandeja antigas, então a integração visual
  depende do ambiente gráfico.
- O aviso de versão da `libcurl` vem do binário do fabricante e, no cenário
  testado, não impede a operação.

## Contribuir

Inclua distribuição, versão, ambiente gráfico, tipo de sessão (Wayland/X11) e
logs relevantes ao relatar um problema. Não publique o `.deb` nem outros
artefatos proprietários da Positivo.

## Licença

Os scripts e a documentação usam a licença MIT. O software Minitela continua
sujeito à licença do fabricante.
